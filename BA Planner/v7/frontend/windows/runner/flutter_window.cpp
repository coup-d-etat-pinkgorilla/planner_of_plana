#include "flutter_window.h"

#include <algorithm>
#include <cmath>
#include <optional>
#include <string>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr char kWindowChannel[] = "ba_planner/window_dock";

bool ParseTargetHandle(const std::string& target_id, HWND* target) {
  constexpr char prefix[] = "hwnd:";
  if (target_id.rfind(prefix, 0) != 0) return false;
  try {
    const auto raw = std::stoull(target_id.substr(sizeof(prefix) - 1), nullptr, 16);
    *target = reinterpret_cast<HWND>(static_cast<uintptr_t>(raw));
    return ::IsWindow(*target) != FALSE;
  } catch (...) {
    return false;
  }
}

int RectWidth(const RECT& rect) { return rect.right - rect.left; }
int RectHeight(const RECT& rect) { return rect.bottom - rect.top; }
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  ConfigureWindowChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RestoreFromScanDock();
  window_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::ConfigureWindowChannel() {
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kWindowChannel,
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "dock") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Error("invalid_arguments", "dock requires arguments");
            return;
          }
          const auto item = arguments->find(flutter::EncodableValue("target_id"));
          if (item == arguments->end() ||
              !std::holds_alternative<std::string>(item->second)) {
            result->Error("invalid_target", "target_id is missing");
            return;
          }
          flutter::EncodableMap response;
          if (!DockBesideTarget(std::get<std::string>(item->second), &response)) {
            result->Error("dock_failed", "could not dock beside the game window");
            return;
          }
          result->Success(flutter::EncodableValue(response));
          return;
        }
        if (call.method_name() == "restore") {
          RestoreFromScanDock();
          result->Success();
          return;
        }
        result->NotImplemented();
      });
}

bool FlutterWindow::DockBesideTarget(const std::string& target_id,
                                     flutter::EncodableMap* result) {
  HWND target = nullptr;
  if (!ParseTargetHandle(target_id, &target)) return false;
  RestoreFromScanDock();

  HWND planner = GetHandle();
  RECT game{};
  planner_restore_placement_ = {sizeof(WINDOWPLACEMENT)};
  target_restore_placement_ = {sizeof(WINDOWPLACEMENT)};
  if (!planner ||
      !::GetWindowPlacement(planner, &planner_restore_placement_) ||
      !::GetWindowPlacement(target, &target_restore_placement_) ||
      !::GetWindowRect(target, &game)) {
    return false;
  }
  const HMONITOR monitor = ::MonitorFromWindow(target, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{sizeof(info)};
  if (!::GetMonitorInfo(monitor, &info)) return false;
  const RECT work = info.rcWork;

  int game_width = RectWidth(game);
  int game_height = RectHeight(game);
  int panel_width = static_cast<int>(std::lround(game_height * 3.0 / 8.0));
  bool resized = false;

  if (game_width + panel_width > RectWidth(work) || game_height > RectHeight(work)) {
    game_width = std::min(1280, RectWidth(work) - panel_width);
    game_height = std::min(720, RectHeight(work));
    if (game_width < 640 || game_height < 360) return false;
    panel_width = static_cast<int>(std::lround(game_height * 3.0 / 8.0));
    resized = true;
  }

  int game_left = game.left;
  int game_top = std::clamp(game.top, work.top, work.bottom - game_height);
  bool place_right = work.right - (game_left + game_width) >= panel_width;
  if (!place_right && game_left - work.left < panel_width) {
    // Move both windows as one group. This is position-only unless the verified
    // 1280x720 fallback above was required, so ratio-based game input remains valid.
    game_left = work.left;
    place_right = true;
  }
  int panel_left = place_right ? game_left + game_width : game_left - panel_width;
  if (panel_left < work.left || panel_left + panel_width > work.right) return false;

  // A maximized window ignores or later overwrites normal-position geometry.
  // Restore both windows before sizing them, then make the game foreground only
  // after the dock has reached its final 3:8 bounds.
  dock_target_ = target;
  scan_docked_ = true;
  ::ShowWindow(target, SW_RESTORE);
  ::ShowWindow(planner, SW_RESTORE);
  if (!::SetWindowPos(target, nullptr, game_left, game_top, game_width,
                      game_height, SWP_NOZORDER | SWP_NOOWNERZORDER)) {
    RestoreFromScanDock();
    return false;
  }
  if (!::SetWindowPos(planner, HWND_TOPMOST, panel_left, game_top, panel_width,
                      game_height, SWP_NOACTIVATE | SWP_SHOWWINDOW)) {
    RestoreFromScanDock();
    return false;
  }
  ::SetForegroundWindow(target);

  result->insert({flutter::EncodableValue("side"),
                  flutter::EncodableValue(place_right ? "right" : "left")});
  result->insert({flutter::EncodableValue("width"),
                  flutter::EncodableValue(panel_width)});
  result->insert({flutter::EncodableValue("height"),
                  flutter::EncodableValue(game_height)});
  result->insert({flutter::EncodableValue("game_resized"),
                  flutter::EncodableValue(resized)});
  return true;
}

void FlutterWindow::RestoreFromScanDock() {
  if (!scan_docked_) return;
  HWND planner = GetHandle();
  if (dock_target_ && ::IsWindow(dock_target_)) {
    ::SetWindowPlacement(dock_target_, &target_restore_placement_);
  }
  if (planner) {
    ::SetWindowPos(planner, HWND_NOTOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    ::SetWindowPlacement(planner, &planner_restore_placement_);
    ::SetForegroundWindow(planner);
  }
  dock_target_ = nullptr;
  scan_docked_ = false;
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
