// ============================================================
// DulceNav — windows/runner/main.cpp
// Punto de entrada nativo de Windows.
// Configura la ventana principal con título y tamaño mínimo.
// ============================================================

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Adjuntar a consola en modo debug para ver logs
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Inicializar COM
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(100, 100);
  // Tamaño inicial de ventana: 1280x720
  Win32Window::Size size(1280, 720);

  if (!window.Create(L"DulceNav - Navegador Privado", origin, size)) {
    return EXIT_FAILURE;
  }

  // Tamaño mínimo de ventana
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
