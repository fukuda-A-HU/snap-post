#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kSingleInstanceMutex[] = L"Local\\SnapPost";
constexpr wchar_t kShowSettingsEvent[] = L"Local\\SnapPostShow";

void FocusRunningSnapPost() {
  HANDLE event =
      ::OpenEventW(EVENT_MODIFY_STATE, FALSE, kShowSettingsEvent);
  if (event != nullptr) {
    ::SetEvent(event);
    ::CloseHandle(event);
  }

  HWND hwnd = nullptr;
  for (int attempt = 0; attempt < 25 && hwnd == nullptr; ++attempt) {
    hwnd = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"SnapPost");
    if (hwnd == nullptr) {
      ::Sleep(40);
    }
  }
  if (hwnd == nullptr) {
    return;
  }
  if (::IsIconic(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  } else {
    ::ShowWindow(hwnd, SW_SHOW);
  }
  ::SetForegroundWindow(hwnd);
  ::BringWindowToTop(hwnd);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // A second launch only raises the running settings window.
  // CreateMutex leaves a stale GetLastError on first creation, so clear it.
  ::SetLastError(0);
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::CloseHandle(instance_mutex);
    FocusRunningSnapPost();
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(900, 760);
  if (!window.Create(L"SnapPost", origin, size)) {
    return EXIT_FAILURE;
  }
  // Closing the settings window hides it. The tray menu exits the process.
  window.SetQuitOnClose(false);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
