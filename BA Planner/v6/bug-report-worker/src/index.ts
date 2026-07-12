import { DurableObject } from "cloudflare:workers";

interface Secrets {
	GITHUB_TOKEN: string;
}

type WorkerEnv = Env & Secrets;

interface ReportPayload {
	title: string;
	body: string;
	diagnosticRecords?: string[];
}

interface GitHubIssueResponse {
	html_url?: string;
	number?: number;
}

interface RateLimitResult {
	success: boolean;
	retryAfterSeconds?: number;
}

const MAX_REQUEST_BYTES = 32 * 1024;
const MAX_TITLE_LENGTH = 200;
const MAX_BODY_LENGTH = 20_000;
const TEN_MINUTES_MS = 10 * 60 * 1000;
const ONE_DAY_MS = 24 * 60 * 60 * 1000;

export class ReportRateLimiter extends DurableObject<Env> {
	constructor(ctx: DurableObjectState, env: Env) {
		super(ctx, env);
		ctx.blockConcurrencyWhile(async () => {
			this.ctx.storage.sql.exec(`
				CREATE TABLE IF NOT EXISTS requests (
					requested_at INTEGER NOT NULL
				);
				CREATE INDEX IF NOT EXISTS requests_requested_at
				ON requests (requested_at);
			`);
		});
	}

	checkAndRecord(now: number): RateLimitResult {
		const dayStart = now - ONE_DAY_MS;
		this.ctx.storage.sql.exec(
			"DELETE FROM requests WHERE requested_at <= ?",
			dayStart,
		);

		const daily = this.ctx.storage.sql
			.exec<{ requested_at: number }>(
				"SELECT requested_at FROM requests ORDER BY requested_at ASC",
			)
			.toArray();
		if (daily.length >= 10) {
			return {
				success: false,
				retryAfterSeconds: secondsUntil(daily[0].requested_at + ONE_DAY_MS, now),
			};
		}

		const tenMinuteStart = now - TEN_MINUTES_MS;
		const recent = daily.filter(
			(entry) => entry.requested_at > tenMinuteStart,
		);
		if (recent.length >= 3) {
			return {
				success: false,
				retryAfterSeconds: secondsUntil(
					recent[0].requested_at + TEN_MINUTES_MS,
					now,
				),
			};
		}

		this.ctx.storage.sql.exec(
			"INSERT INTO requests (requested_at) VALUES (?)",
			now,
		);
		return { success: true };
	}
}

function secondsUntil(target: number, now: number): number {
	return Math.max(1, Math.ceil((target - now) / 1000));
}

function isReportPayload(value: unknown): value is ReportPayload {
	if (typeof value !== "object" || value === null) {
		return false;
	}

	const payload = value as Record<string, unknown>;
	const keys = Object.keys(payload).sort();
	const validKeys =
		(keys.length === 2 && keys[0] === "body" && keys[1] === "title") ||
		(keys.length === 3 &&
			keys[0] === "body" &&
			keys[1] === "diagnosticRecords" &&
			keys[2] === "title");
	return (
		validKeys &&
		typeof payload.title === "string" &&
		payload.title.trim().length > 0 &&
		payload.title.trim().length <= MAX_TITLE_LENGTH &&
		typeof payload.body === "string" &&
		payload.body.trim().length > 0 &&
		payload.body.trim().length <= MAX_BODY_LENGTH &&
		(payload.diagnosticRecords === undefined ||
			(Array.isArray(payload.diagnosticRecords) &&
				payload.diagnosticRecords.every(
					(record) => typeof record === "string" && record.trim().length > 0,
				)))
	);
}

function githubHeaders(env: WorkerEnv): Record<string, string> {
	return {
		Accept: "application/vnd.github+json",
		Authorization: `Bearer ${env.GITHUB_TOKEN}`,
		"Content-Type": "application/json",
		"User-Agent": "BA-Planner-Bug-Report-Worker",
		"X-GitHub-Api-Version": "2026-03-10",
	};
}

function diagnosticComment(records: string[]): string {
	const sections = records.map((record, index) => {
		const indented = record
			.split("\n")
			.map((line) => `    ${line}`)
			.join("\n");
		return `### Diagnostic record set ${index + 1}\n\n${indented}`;
	});
	return [
		"## Complete diagnostic records",
		"",
		"<details><summary>Show privacy-scrubbed raw diagnostics</summary>",
		"",
		sections.join("\n\n"),
		"",
		"</details>",
	].join("\n");
}

async function hashClientAddress(address: string): Promise<string> {
	const encoded = new TextEncoder().encode(address);
	const digest = await crypto.subtle.digest("SHA-256", encoded);
	return Array.from(new Uint8Array(digest), (byte) =>
		byte.toString(16).padStart(2, "0"),
	).join("");
}

export default {
	async fetch(request, env): Promise<Response> {
		const requestId = crypto.randomUUID();
		const startedAt = Date.now();
		const respond = (
			status: number,
			body: Record<string, unknown>,
			extraHeaders?: HeadersInit,
		): Response => {
			console.log(
				JSON.stringify({
					requestId,
					status,
					durationMs: Date.now() - startedAt,
				}),
			);
			return Response.json(
				{ ...body, requestId },
				{
					status,
					headers: {
						"Cache-Control": "no-store",
						"X-Content-Type-Options": "nosniff",
						"X-Request-ID": requestId,
						...extraHeaders,
					},
				},
			);
		};
		const error = (
			status: number,
			code: string,
			message: string,
			extraHeaders?: HeadersInit,
		): Response =>
			respond(status, { error: { code, message } }, extraHeaders);

		const url = new URL(request.url);
		if (url.pathname !== "/report") {
			return error(404, "NOT_FOUND", "Not found");
		}
		if (request.method !== "POST") {
			return error(405, "METHOD_NOT_ALLOWED", "Method not allowed", {
				Allow: "POST",
			});
		}
		if (env.REPORTING_ENABLED !== "true") {
			return error(503, "REPORTING_DISABLED", "Reporting is temporarily disabled");
		}

		const contentType = request.headers.get("Content-Type") ?? "";
		if (contentType.split(";", 1)[0].trim().toLowerCase() !== "application/json") {
			return error(415, "UNSUPPORTED_MEDIA_TYPE", "Content-Type must be application/json");
		}
		const declaredLength = Number(request.headers.get("Content-Length"));
		if (Number.isFinite(declaredLength) && declaredLength > MAX_REQUEST_BYTES) {
			return error(413, "PAYLOAD_TOO_LARGE", "Report is too large");
		}

		const bodyBytes = await request.arrayBuffer();
		if (bodyBytes.byteLength > MAX_REQUEST_BYTES) {
			return error(413, "PAYLOAD_TOO_LARGE", "Report is too large");
		}

		let payload: unknown;
		try {
			payload = JSON.parse(new TextDecoder().decode(bodyBytes));
		} catch {
			return error(400, "INVALID_JSON", "Request body must be valid JSON");
		}
		if (!isReportPayload(payload)) {
			return error(
				400,
				"INVALID_PAYLOAD",
				"title and body must be the only fields and must meet length limits",
			);
		}
		if (!env.GITHUB_TOKEN || !env.GITHUB_OWNER || !env.GITHUB_REPO) {
			return error(500, "WORKER_NOT_CONFIGURED", "Worker is not configured");
		}

		const clientAddress = request.headers.get("CF-Connecting-IP");
		if (!clientAddress) {
			return error(400, "CLIENT_ADDRESS_UNAVAILABLE", "Client address is unavailable");
		}
		try {
			const clientKey = await hashClientAddress(clientAddress);
			const limiter = env.REPORT_RATE_LIMITER.getByName(clientKey);
			const rateLimit = await limiter.checkAndRecord(Date.now());
			if (!rateLimit.success) {
				const retryAfter = String(rateLimit.retryAfterSeconds ?? 1);
				return error(429, "RATE_LIMITED", "Too many reports", {
					"Retry-After": retryAfter,
				});
			}
		} catch {
			return error(503, "RATE_LIMIT_UNAVAILABLE", "Reporting is temporarily unavailable");
		}

		let githubResponse: Response;
		try {
			githubResponse = await fetch(
				`https://api.github.com/repos/${encodeURIComponent(env.GITHUB_OWNER)}/${encodeURIComponent(env.GITHUB_REPO)}/issues`,
				{
					method: "POST",
					headers: githubHeaders(env),
					body: JSON.stringify({
						title: payload.title.trim(),
						body: payload.body.trim(),
					}),
				},
			);
		} catch {
			return error(502, "GITHUB_UNAVAILABLE", "GitHub is unavailable");
		}
		if (!githubResponse.ok) {
			return error(502, "GITHUB_REJECTED", "GitHub rejected the issue");
		}

		let issue: GitHubIssueResponse;
		try {
			issue = (await githubResponse.json()) as GitHubIssueResponse;
		} catch {
			return error(502, "GITHUB_INVALID_RESPONSE", "GitHub returned an invalid response");
		}
		let diagnosticsUploaded = true;
		let warning = "";
		const diagnosticRecords = payload.diagnosticRecords ?? [];
		if (diagnosticRecords.length > 0) {
			diagnosticsUploaded = false;
			if (issue.number !== undefined) {
				try {
					const commentResponse = await fetch(
						`https://api.github.com/repos/${encodeURIComponent(env.GITHUB_OWNER)}/${encodeURIComponent(env.GITHUB_REPO)}/issues/${issue.number}/comments`,
						{
							method: "POST",
							headers: githubHeaders(env),
							body: JSON.stringify({ body: diagnosticComment(diagnosticRecords) }),
						},
					);
					diagnosticsUploaded = commentResponse.ok;
				} catch {
					diagnosticsUploaded = false;
				}
			}

			if (!diagnosticsUploaded) {
				warning = "Complete diagnostic records could not be attached";
				if (issue.number !== undefined) {
					try {
						await fetch(
							`https://api.github.com/repos/${encodeURIComponent(env.GITHUB_OWNER)}/${encodeURIComponent(env.GITHUB_REPO)}/issues/${issue.number}`,
							{
								method: "PATCH",
								headers: githubHeaders(env),
								body: JSON.stringify({
									body: `${payload.body.trim()}\n\n> ⚠️ ${warning}.`,
								}),
							},
						);
					} catch {
						// The response still reports the partial failure to the desktop app.
					}
				}
			}
		}

		return respond(201, {
			issueUrl: issue.html_url ?? null,
			issueNumber: issue.number ?? null,
			diagnosticsUploaded,
			warning: warning || null,
		});
	},
} satisfies ExportedHandler<WorkerEnv>;
