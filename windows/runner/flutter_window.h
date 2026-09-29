#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <shobjidl.h>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      media_channel_;
  ITaskbarList3* taskbar_ = nullptr;
  HICON previous_icon_ = nullptr;
  HICON play_icon_ = nullptr;
  HICON pause_icon_ = nullptr;
  HICON next_icon_ = nullptr;
  bool is_playing_ = false;
  bool thumbar_added_ = false;
  UINT taskbar_button_created_message_ = 0;

  static constexpr int kHotkeyPlayPause = 5001;
  static constexpr int kHotkeyNextTrack = 5002;
  static constexpr int kHotkeyPrevTrack = 5003;
  static constexpr int kHotkeyStop = 5004;
  static constexpr int kHotkeyGlobalPlay = 5005;
  static constexpr int kHotkeyGlobalNext = 5006;
  static constexpr int kHotkeyGlobalPrev = 5007;

  ULONGLONG last_media_action_tick_ = 0;
  bool hotkeys_registered_ = false;

  void SetupMediaChannel();
  void SetupThumbar();
  void UpdateThumbar();
  void RegisterGlobalMediaHotkeys();
  void UnregisterGlobalMediaHotkeys();
  void SendMediaAction(const char* action);
  void SendMediaActionWithValue(const char* action,
                                const flutter::EncodableValue& value);
  void DisposeWindowsMedia();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
