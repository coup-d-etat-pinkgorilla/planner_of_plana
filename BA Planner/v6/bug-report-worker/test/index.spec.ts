import {
	createExecutionContext,
	env,
	waitOnExecutionContext,
} from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../src/index";

const IncomingRequest = Request<unknown, IncomingRequestCfProperties>;
const testEnv = env as Env & { GITHUB_TOKEN: string };
testEnv.GITHUB_TOKEN = "test-token";

function reportRequest(
	payload: unknown = { title: "Test issue", body: "Details" },
	init: RequestInit = {},
): Request {
	return new IncomingRequest("https://worker.example/report", {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			"CF-Connecting-IP": "203.0.113.10",
			...init.headers,
		},
		body: JSON.stringify(payload),
		...init,
	});
}

async function dispatch(request: Request): Promise<Response> {
	const ctx = createExecutionContext();
	const response = await worker.fetch(request, testEnv, ctx);
	await waitOnExecutionContext(ctx);
	return response;
}

function mockGitHubSuccess() {
	return vi.spyOn(globalThis, "fetch").mockImplementation(async () =>
		Response.json(
			{ html_url: "https://github.com/example/issues/42", number: 42 },
			{ status: 201 },
		),
	);
}

afterEach(() => {
	vi.restoreAllMocks();
});

describe("bug report worker", () => {
	it("creates a GitHub issue for POST /report", async () => {
		const githubFetch = mockGitHubSuccess();
		const response = await dispatch(
			reportRequest({ title: " Test issue ", body: " Details " }),
		);
		const result = (await response.json()) as Record<string, unknown>;

		expect(response.status).toBe(201);
		expect(result.issueUrl).toBe("https://github.com/example/issues/42");
		expect(result.issueNumber).toBe(42);
		expect(result.diagnosticsUploaded).toBe(true);
		expect(result.warning).toBeNull();
		expect(result.requestId).toEqual(expect.any(String));
		expect(response.headers.get("X-Request-ID")).toBe(result.requestId);
		expect(githubFetch).toHaveBeenCalledOnce();
		const [url, init] = githubFetch.mock.calls[0];
		expect(url).toBe(
			"https://api.github.com/repos/coup-d-etat-pinkgorilla/planner_of_plana/issues",
		);
		expect(JSON.parse(String(init?.body))).toEqual({
			title: "Test issue",
			body: "Details",
		});
	});

	it("adds complete diagnostic records as an issue comment", async () => {
		const githubFetch = vi.spyOn(globalThis, "fetch").mockImplementation(
			async (input) => {
				const url = String(input);
				if (url.endsWith("/comments")) {
					return Response.json({ id: 99 }, { status: 201 });
				}
				return Response.json(
					{ html_url: "https://github.com/example/issues/42", number: 42 },
					{ status: 201 },
				);
			},
		);
		const completeRecord =
			"2026-07-12 ERROR complete failure\nTraceback line\nRuntimeError: detail";
		const response = await dispatch(
			reportRequest({
				title: "Test issue",
				body: "Compact summary",
				diagnosticRecords: [completeRecord],
			}),
		);
		const result = (await response.json()) as Record<string, unknown>;

		expect(response.status).toBe(201);
		expect(result.diagnosticsUploaded).toBe(true);
		expect(githubFetch).toHaveBeenCalledTimes(2);
		const [commentUrl, commentInit] = githubFetch.mock.calls[1];
		expect(String(commentUrl)).toContain("/issues/42/comments");
		const commentPayload = JSON.parse(String(commentInit?.body));
		expect(commentPayload.body).toContain(completeRecord.replaceAll("\n", "\n    "));
	});

	it("marks the issue when diagnostic comment upload fails", async () => {
		const githubFetch = vi
			.spyOn(globalThis, "fetch")
			.mockResolvedValueOnce(
				Response.json(
					{ html_url: "https://github.com/example/issues/42", number: 42 },
					{ status: 201 },
				),
			)
			.mockResolvedValueOnce(Response.json({ message: "failed" }, { status: 500 }))
			.mockResolvedValueOnce(Response.json({}, { status: 200 }));
		const response = await dispatch(
			reportRequest({
				title: "Test issue",
				body: "Compact summary",
				diagnosticRecords: ["complete raw record"],
			}),
		);
		const result = (await response.json()) as Record<string, unknown>;

		expect(response.status).toBe(201);
		expect(result.diagnosticsUploaded).toBe(false);
		expect(result.warning).toBe(
			"Complete diagnostic records could not be attached",
		);
		expect(githubFetch).toHaveBeenCalledTimes(3);
		const [, patchInit] = githubFetch.mock.calls[2];
		expect(patchInit?.method).toBe("PATCH");
		expect(JSON.parse(String(patchInit?.body)).body).toContain("⚠️");
	});

	it("rejects invalid JSON", async () => {
		const response = await dispatch(
			reportRequest(undefined, { body: "not-json" }),
		);
		const result = (await response.json()) as {
			error: { code: string };
		};

		expect(response.status).toBe(400);
		expect(result.error.code).toBe("INVALID_JSON");
	});

	it.each([
		{},
		{ title: "", body: "Details" },
		{ title: "Title", body: "   " },
		{ title: "Title", body: "Details", extra: true },
		{ title: "Title", body: "Details", diagnosticRecords: [""] },
		{ title: "Title", body: "Details", diagnosticRecords: [123] },
		{ title: "x".repeat(201), body: "Details" },
		{ title: "Title", body: "x".repeat(20_001) },
	])("rejects an invalid payload", async (payload) => {
		const response = await dispatch(reportRequest(payload));
		expect(response.status).toBe(400);
	});

	it("rejects a request larger than 32 KiB", async () => {
		const response = await dispatch(
			reportRequest(undefined, {
				body: "x".repeat(32 * 1024 + 1),
			}),
		);
		expect(response.status).toBe(413);
	});

	it("requires application/json", async () => {
		const response = await dispatch(
			reportRequest(undefined, {
				headers: {
					"Content-Type": "text/plain",
					"CF-Connecting-IP": "203.0.113.10",
				},
			}),
		);
		expect(response.status).toBe(415);
	});

	it("does not enable browser CORS", async () => {
		const response = await dispatch(
			new IncomingRequest("https://worker.example/report", {
				method: "OPTIONS",
			}),
		);
		expect(response.status).toBe(405);
		expect(response.headers.has("Access-Control-Allow-Origin")).toBe(false);
	});

	it("returns 404 for unknown paths", async () => {
		const response = await dispatch(
			new IncomingRequest("https://worker.example/"),
		);
		expect(response.status).toBe(404);
	});

	it("can disable reporting without changing code", async () => {
		const original = testEnv.REPORTING_ENABLED;
		testEnv.REPORTING_ENABLED = "false";
		try {
			const response = await dispatch(reportRequest());
			expect(response.status).toBe(503);
			const result = (await response.json()) as {
				error: { code: string };
			};
			expect(result.error.code).toBe("REPORTING_DISABLED");
		} finally {
			testEnv.REPORTING_ENABLED = original;
		}
	});

	it("limits an IP to three reports in ten minutes", async () => {
		mockGitHubSuccess();
		for (let attempt = 0; attempt < 3; attempt += 1) {
			const response = await dispatch(reportRequest());
			expect(response.status).toBe(201);
		}

		const blocked = await dispatch(reportRequest());
		expect(blocked.status).toBe(429);
		expect(Number(blocked.headers.get("Retry-After"))).toBeGreaterThan(0);
	});

	it("limits an IP to ten reports in a rolling day", async () => {
		const limiter = testEnv.REPORT_RATE_LIMITER.getByName(
			`daily-test-${crypto.randomUUID()}`,
		);
		const start = Date.now();
		for (let attempt = 0; attempt < 10; attempt += 1) {
			const result = await limiter.checkAndRecord(
				start + attempt * 61 * 60 * 1000,
			);
			expect(result.success).toBe(true);
		}
		const blocked = await limiter.checkAndRecord(start + 10 * 61 * 60 * 1000);
		expect(blocked.success).toBe(false);
		expect(blocked.retryAfterSeconds).toBeGreaterThan(0);
	});

	it("does not expose GitHub error details", async () => {
		vi.spyOn(globalThis, "fetch").mockResolvedValue(
			Response.json({ message: "sensitive upstream detail" }, { status: 401 }),
		);
		const response = await dispatch(reportRequest());
		const result = (await response.json()) as {
			error: { code: string; message: string };
		};

		expect(response.status).toBe(502);
		expect(result.error).toEqual({
			code: "GITHUB_REJECTED",
			message: "GitHub rejected the issue",
		});
		expect(JSON.stringify(result)).not.toContain("sensitive upstream detail");
	});
});
