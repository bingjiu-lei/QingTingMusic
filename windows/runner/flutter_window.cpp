#include "flutter_window.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <optional>
#include <shobjidl.h>
#include <string>
#include <windowsx.h>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr UINT kPreviousButton = 4101;
constexpr UINT kPlayButton = 4102;
constexpr UINT kNextButton = 4103;
constexpr UINT kDesktopLyricsCloseButton = 4104;
constexpr wchar_t kDesktopLyricClass[] = L"QingTingDesktopLyric";
constexpr COLORREF kLyricTransparentColor = RGB(1, 2, 3);

struct DesktopLyricState {
  HWND window = nullptr;
  HWND owner = nullptr;
  std::wstring text;
  std::wstring secondary;
  double progress = 0.0;
  bool dark = false;
  bool playing = false;
  bool hovered = false;
  bool tracking_mouse = false;
  COLORREF accent = RGB(47, 139, 255);
  HFONT title_font = nullptr;
  HFONT secondary_font = nullptr;
  HFONT control_font = nullptr;
} g_lyric;

RECT LyricControlRect(const RECT& client, int index) {
  constexpr int button = 30;
  constexpr int gap = 8;
  constexpr int count = 4;
  const int total = button * count + gap * (count - 1);
  const int left = (client.right - total) / 2 + index * (button + gap);
  return {left, client.bottom - 34, left + button, client.bottom - 4};
}

int HitLyricControl(HWND hwnd, POINT point) {
  RECT client;
  GetClientRect(hwnd, &client);
  for (int index = 0; index < 4; ++index) {
    RECT target = LyricControlRect(client, index);
    if (PtInRect(&target, point)) return index;
  }
  return -1;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) return L"";
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.c_str(),
                                       static_cast<int>(value.size()), nullptr, 0);
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(),
                      static_cast<int>(value.size()), result.data(), size);
  return result;
}

HICON CreateMediaIcon(int type) {
  constexpr int size = 32;
  BITMAPINFO info = {};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = size;
  info.bmiHeader.biHeight = -size;
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  void* raw = nullptr;
  HDC screen = GetDC(nullptr);
  HBITMAP color = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &raw, nullptr, 0);
  ReleaseDC(nullptr, screen);
  if (!color || !raw) return nullptr;
  auto* pixels = static_cast<unsigned int*>(raw);
  auto put = [&](int x, int y) {
    if (x >= 0 && x < size && y >= 0 && y < size)
      pixels[y * size + x] = 0xFF2788F5;
  };
  auto bar = [&](int x) {
    for (int y = 8; y <= 24; ++y)
      for (int dx = 0; dx < 3; ++dx) put(x + dx, y);
  };
  auto triangle = [&](bool right, int center_x) {
    for (int y = -8; y <= 8; ++y) {
      const int width = 8 - std::abs(y);
      for (int x = 0; x <= width; ++x) put(center_x + (right ? x : -x), 16 + y);
    }
  };
  if (type == 0) { bar(7); triangle(false, 23); }
  if (type == 1) triangle(true, 11);
  if (type == 2) { bar(10); bar(19); }
  if (type == 3) { triangle(true, 9); bar(23); }
  HBITMAP mask = CreateBitmap(size, size, 1, 1, nullptr);
  ICONINFO icon_info = {TRUE, 0, 0, mask, color};
  HICON icon = CreateIconIndirect(&icon_info);
  DeleteObject(mask);
  DeleteObject(color);
  return icon;
}

LRESULT CALLBACK DesktopLyricProc(HWND hwnd, UINT message, WPARAM wparam,
                                  LPARAM lparam) {
  switch (message) {
    case WM_NCHITTEST: {
      POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      ScreenToClient(hwnd, &point);
      if (HitLyricControl(hwnd, point) >= 0) return HTCLIENT;
      return HTCAPTION;
    }
    case WM_MOUSEMOVE: {
      if (!g_lyric.tracking_mouse) {
        TRACKMOUSEEVENT tracking = {sizeof(TRACKMOUSEEVENT), TME_LEAVE, hwnd, 0};
        TrackMouseEvent(&tracking);
        g_lyric.tracking_mouse = true;
      }
      if (!g_lyric.hovered) {
        g_lyric.hovered = true;
        InvalidateRect(hwnd, nullptr, FALSE);
      }
      return 0;
    }
    case WM_MOUSELEAVE:
      g_lyric.tracking_mouse = false;
      g_lyric.hovered = false;
      InvalidateRect(hwnd, nullptr, FALSE);
      return 0;
    case WM_SETCURSOR: {
      POINT point;
      GetCursorPos(&point);
      ScreenToClient(hwnd, &point);
      if (HitLyricControl(hwnd, point) >= 0) {
        SetCursor(LoadCursor(nullptr, IDC_HAND));
        return TRUE;
      }
      break;
    }
    case WM_LBUTTONUP: {
      POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      const int action = HitLyricControl(hwnd, point);
      if (action == 0 && g_lyric.owner)
        PostMessage(g_lyric.owner, WM_COMMAND, kPreviousButton, 0);
      if (action == 1 && g_lyric.owner)
        PostMessage(g_lyric.owner, WM_COMMAND, kPlayButton, 0);
      if (action == 2 && g_lyric.owner)
        PostMessage(g_lyric.owner, WM_COMMAND, kNextButton, 0);
      if (action == 3) {
        ShowWindow(hwnd, SW_HIDE);
        if (g_lyric.owner)
          PostMessage(g_lyric.owner, WM_COMMAND, kDesktopLyricsCloseButton, 0);
      }
      return 0;
    }
    case WM_PAINT: {
      PAINTSTRUCT ps;
      HDC dc = BeginPaint(hwnd, &ps);
      RECT rect;
      GetClientRect(hwnd, &rect);
      HBRUSH background = CreateSolidBrush(kLyricTransparentColor);
      FillRect(dc, &rect, background);
      DeleteObject(background);
      SetBkMode(dc, TRANSPARENT);
      HFONT old = static_cast<HFONT>(SelectObject(dc, g_lyric.title_font));
      RECT title = {28, 6, rect.right - 28, 52};
      RECT shadow = title;
      OffsetRect(&shadow, 1, 1);
      SetTextColor(dc, g_lyric.dark ? RGB(10, 12, 16) : RGB(255, 255, 255));
      DrawTextW(dc, g_lyric.text.c_str(), -1, &shadow,
                DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
      SetTextColor(dc, g_lyric.dark ? RGB(210, 216, 226) : RGB(82, 91, 105));
      DrawTextW(dc, g_lyric.text.c_str(), -1, &title,
                DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
      SIZE title_size = {};
      GetTextExtentPoint32W(dc, g_lyric.text.c_str(),
                            static_cast<int>(g_lyric.text.size()), &title_size);
      int saved = SaveDC(dc);
      const int text_left = std::max(
          title.left, (title.left + title.right - title_size.cx) / 2);
      const int clip_right = text_left + static_cast<int>(
          title_size.cx * std::clamp(g_lyric.progress, 0.0, 1.0));
      IntersectClipRect(dc, text_left, title.top, clip_right, title.bottom);
      SetTextColor(dc, g_lyric.accent);
      DrawTextW(dc, g_lyric.text.c_str(), -1, &title,
                DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
      RestoreDC(dc, saved);
      if (!g_lyric.secondary.empty()) {
        SelectObject(dc, g_lyric.secondary_font);
        RECT sub = {28, 48, rect.right - 28, 84};
        SetTextColor(dc, g_lyric.dark ? RGB(158, 168, 182) : RGB(112, 122, 137));
        DrawTextW(dc, g_lyric.secondary.c_str(), -1, &sub,
                  DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
      }
      if (g_lyric.hovered) {
        SelectObject(dc, g_lyric.control_font);
        const wchar_t* glyphs[4] = {L"\xE892", g_lyric.playing ? L"\xE769" : L"\xE768",
                                    L"\xE893", L"\xE8BB"};
        for (int index = 0; index < 4; ++index) {
          RECT button = LyricControlRect(rect, index);
          HBRUSH fill = CreateSolidBrush(g_lyric.dark ? RGB(35, 39, 47)
                                                       : RGB(244, 247, 251));
          HPEN pen = CreatePen(PS_SOLID, 1, g_lyric.dark ? RGB(69, 76, 88)
                                                         : RGB(218, 224, 233));
          HGDIOBJ old_brush = SelectObject(dc, fill);
          HGDIOBJ old_pen = SelectObject(dc, pen);
          RoundRect(dc, button.left, button.top, button.right, button.bottom, 10, 10);
          SelectObject(dc, old_brush);
          SelectObject(dc, old_pen);
          DeleteObject(fill);
          DeleteObject(pen);
          SetTextColor(dc, g_lyric.dark ? RGB(218, 224, 234) : RGB(91, 101, 116));
          DrawTextW(dc, glyphs[index], -1, &button,
                    DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        }
      }
      SelectObject(dc, old);
      EndPaint(hwnd, &ps);
      return 0;
    }
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

HWND EnsureDesktopLyricWindow(HWND owner) {
  g_lyric.owner = owner;
  if (g_lyric.window) return g_lyric.window;
  WNDCLASSW window_class = {};
  window_class.lpfnWndProc = DesktopLyricProc;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.hCursor = LoadCursor(nullptr, IDC_SIZEALL);
  window_class.lpszClassName = kDesktopLyricClass;
  RegisterClassW(&window_class);
  const int width = 820;
  const int height = 124;
  const int x = (GetSystemMetrics(SM_CXSCREEN) - width) / 2;
  const int y = GetSystemMetrics(SM_CYSCREEN) - height - 110;
  g_lyric.window = CreateWindowExW(
      WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_NOACTIVATE,
      kDesktopLyricClass, L"QingTing Desktop Lyrics", WS_POPUP, x, y, width,
      height, nullptr,
      nullptr, GetModuleHandle(nullptr), nullptr);
  if (g_lyric.window) {
    g_lyric.title_font = CreateFontW(
        -25, 0, 0, 0, FW_MEDIUM, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY,
        DEFAULT_PITCH, L"Microsoft YaHei UI");
    g_lyric.secondary_font = CreateFontW(
        -16, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY,
        DEFAULT_PITCH, L"Microsoft YaHei UI");
    g_lyric.control_font = CreateFontW(
        -16, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
        OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY,
        DEFAULT_PITCH, L"Segoe MDL2 Assets");
    SetLayeredWindowAttributes(g_lyric.window, kLyricTransparentColor, 255,
                               LWA_COLORKEY);
  }
  return g_lyric.window;
}
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
  taskbar_button_created_message_ =
      RegisterWindowMessageW(L"TaskbarButtonCreated");
  SetupMediaChannel();
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
  DisposeWindowsMedia();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == taskbar_button_created_message_) {
    thumbar_added_ = false;
    SetupThumbar();
    return 0;
  }
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
    case WM_COMMAND:
      if (LOWORD(wparam) == kPreviousButton) SendMediaAction("previous");
      if (LOWORD(wparam) == kPlayButton) SendMediaAction("togglePlay");
      if (LOWORD(wparam) == kNextButton) SendMediaAction("next");
      if (LOWORD(wparam) == kDesktopLyricsCloseButton)
        SendMediaAction("desktopLyricsClosed");
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SetupMediaChannel() {
  media_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "qingting/windows_media",
      &flutter::StandardMethodCodec::GetInstance());
  media_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "initialize") {
          SetupThumbar();
          result->Success();
          return;
        }
        if (call.method_name() == "updatePlayback") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto it = args->find(flutter::EncodableValue("isPlaying"));
            if (it != args->end()) {
              is_playing_ = std::get<bool>(it->second);
              g_lyric.playing = is_playing_;
            }
          }
          UpdateThumbar();
          if (g_lyric.window) InvalidateRect(g_lyric.window, nullptr, FALSE);
          result->Success();
          return;
        }
        if (call.method_name() == "showDesktopLyrics") {
          const bool visible = call.arguments() && std::get<bool>(*call.arguments());
          HWND lyric = EnsureDesktopLyricWindow(GetHandle());
          if (lyric) ShowWindow(lyric, visible ? SW_SHOWNOACTIVATE : SW_HIDE);
          result->Success();
          return;
        }
        if (call.method_name() == "updateDesktopLyrics") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto string_value = [&](const char* key) {
              const auto it = args->find(flutter::EncodableValue(key));
              return it == args->end() ? std::string() : std::get<std::string>(it->second);
            };
            g_lyric.text = Utf8ToWide(string_value("text"));
            g_lyric.secondary = Utf8ToWide(string_value("secondary"));
            const auto progress = args->find(flutter::EncodableValue("progress"));
            if (progress != args->end()) {
              if (const auto* progress_double =
                      std::get_if<double>(&progress->second)) {
                g_lyric.progress = *progress_double;
              } else if (const auto* progress_32 =
                             std::get_if<int32_t>(&progress->second)) {
                g_lyric.progress = static_cast<double>(*progress_32);
              } else if (const auto* progress_64 =
                             std::get_if<int64_t>(&progress->second)) {
                g_lyric.progress = static_cast<double>(*progress_64);
              }
            }
            const auto dark = args->find(flutter::EncodableValue("dark"));
            if (dark != args->end()) {
              if (const auto* value = std::get_if<bool>(&dark->second)) {
                g_lyric.dark = *value;
              }
            }
            const auto accent = args->find(flutter::EncodableValue("accent"));
            if (accent != args->end()) {
              unsigned int value = 0;
              bool valid = false;
              if (const auto* accent_32 =
                      std::get_if<int32_t>(&accent->second)) {
                value = static_cast<unsigned int>(*accent_32);
                valid = true;
              } else if (const auto* accent_64 =
                             std::get_if<int64_t>(&accent->second)) {
                value = static_cast<unsigned int>(*accent_64);
                valid = true;
              }
              if (valid) {
                g_lyric.accent =
                    RGB((value >> 16) & 0xFF, (value >> 8) & 0xFF,
                        value & 0xFF);
              }
            }
          }
          if (g_lyric.window) InvalidateRect(g_lyric.window, nullptr, FALSE);
          result->Success();
          return;
        }
        if (call.method_name() == "dispose") {
          DisposeWindowsMedia();
          result->Success();
          return;
        }
        result->NotImplemented();
      });
}

void FlutterWindow::SetupThumbar() {
  if (!taskbar_) {
    if (FAILED(CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&taskbar_)))) return;
    if (FAILED(taskbar_->HrInit())) return;
    previous_icon_ = CreateMediaIcon(0);
    play_icon_ = CreateMediaIcon(1);
    pause_icon_ = CreateMediaIcon(2);
    next_icon_ = CreateMediaIcon(3);
  }
  if (thumbar_added_) return;
  THUMBBUTTON buttons[3] = {};
  const UINT ids[3] = {kPreviousButton, kPlayButton, kNextButton};
  HICON icons[3] = {previous_icon_, play_icon_, next_icon_};
  const wchar_t* tips[3] = {L"上一首", L"播放", L"下一首"};
  for (int i = 0; i < 3; ++i) {
    buttons[i].dwMask = THB_ICON | THB_TOOLTIP | THB_FLAGS;
    buttons[i].iId = ids[i];
    buttons[i].hIcon = icons[i];
    buttons[i].dwFlags = THBF_ENABLED;
    wcscpy_s(buttons[i].szTip, tips[i]);
  }
  thumbar_added_ =
      SUCCEEDED(taskbar_->ThumbBarAddButtons(GetHandle(), 3, buttons));
}

void FlutterWindow::UpdateThumbar() {
  if (!taskbar_ || !thumbar_added_) return;
  THUMBBUTTON button = {};
  button.dwMask = THB_ICON | THB_TOOLTIP;
  button.iId = kPlayButton;
  button.hIcon = is_playing_ ? pause_icon_ : play_icon_;
  wcscpy_s(button.szTip, is_playing_ ? L"暂停" : L"播放");
  taskbar_->ThumbBarUpdateButtons(GetHandle(), 1, &button);
}

void FlutterWindow::SendMediaAction(const char* action) {
  if (media_channel_) media_channel_->InvokeMethod(action, nullptr);
}

void FlutterWindow::DisposeWindowsMedia() {
  if (g_lyric.window) {
    DestroyWindow(g_lyric.window);
    g_lyric.window = nullptr;
  }
  for (HFONT font : {g_lyric.title_font, g_lyric.secondary_font,
                     g_lyric.control_font})
    if (font) DeleteObject(font);
  g_lyric.title_font = nullptr;
  g_lyric.secondary_font = nullptr;
  g_lyric.control_font = nullptr;
  g_lyric.owner = nullptr;
  if (taskbar_) { taskbar_->Release(); taskbar_ = nullptr; }
  thumbar_added_ = false;
  for (HICON icon : {previous_icon_, play_icon_, pause_icon_, next_icon_})
    if (icon) DestroyIcon(icon);
  previous_icon_ = play_icon_ = pause_icon_ = next_icon_ = nullptr;
  media_channel_.reset();
}
