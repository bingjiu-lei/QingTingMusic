#include "flutter_window.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <gdiplus.h>
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
constexpr UINT kDesktopLyricsLockChangedNotify = 4105;
constexpr UINT kDesktopLyricsMovedNotify = 4106;
constexpr wchar_t kDesktopLyricClass[] = L"QingTingDesktopLyric";
constexpr UINT_PTR kDesktopLyricTimer = 1;
constexpr UINT kDesktopLyricFrameMs = 25;
constexpr int kDesktopLyricControlCount = 5;
constexpr int kDesktopLyricUnlockControl = 100;
constexpr double kDesktopLyricMinFontSize = 20.0;
constexpr double kDesktopLyricMaxFontSize = 44.0;
constexpr double kDesktopLyricToolbarHeight = 43.0;
constexpr double kDesktopLyricTitleGap = 4.0;
constexpr double kDesktopLyricBottomPadding = 20.0;

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
  int hot_control = -1;
  int pressed_control = -1;
  bool drag_pending = false;
  bool dragging = false;
  POINT drag_start = {};
  RECT drag_window = {};
  double hover_amount = 0.0;
  double progress_velocity = 0.0;
  ULONGLONG progress_tick = 0;
  COLORREF accent = RGB(47, 139, 255);
  // User style pushed from Dart (logical px / ARGB values).
  double font_size = 28.0;
  unsigned int text_color = 0;    // ARGB, 0 = auto by theme.
  unsigned int stroke_color = 0;  // ARGB, 0 = auto by theme.
  double stroke_width = 1.6;      // Logical px, 0 = stroke disabled.
  bool locked = false;
  bool has_saved_position = false;
  double saved_x = 0.0;  // Logical px, window top-left on screen.
  double saved_y = 0.0;
  // Locked-mode interaction runtime state.
  bool click_through = false;
  bool cursor_inside = false;
  bool unlock_hot = false;
  ULONG_PTR gdiplus_token = 0;
  HDC buffer_dc = nullptr;
  HBITMAP buffer_bitmap = nullptr;
  HGDIOBJ buffer_old_bitmap = nullptr;
  void* buffer_bits = nullptr;
  int buffer_width = 0;
  int buffer_height = 0;
} g_lyric;

float LyricScale(HWND hwnd) {
  const UINT dpi = hwnd ? GetDpiForWindow(hwnd) : GetDpiForSystem();
  return std::max(1.0f, static_cast<float>(dpi) / 96.0f);
}

RECT LyricControlRect(HWND hwnd, const RECT& client, int index) {
  const float scale = LyricScale(hwnd);
  const int button = static_cast<int>(32 * scale);
  const int gap = static_cast<int>(8 * scale);
  constexpr int count = 4;
  const int total = button * count + gap * (count - 1);
  const int left = (client.right - total) / 2 + index * (button + gap);
  const int top = static_cast<int>(7 * scale);
  return {left, top, left + button, top + button};
}

int HitLyricControl(HWND hwnd, POINT point) {
  RECT client;
  GetClientRect(hwnd, &client);
  for (int index = 0; index < 4; ++index) {
    RECT target = LyricControlRect(hwnd, client, index);
    if (PtInRect(&target, point)) return index;
  }
  return -1;
}

void ReleaseLyricBuffer() {
  if (g_lyric.buffer_dc) {
    if (g_lyric.buffer_old_bitmap)
      SelectObject(g_lyric.buffer_dc, g_lyric.buffer_old_bitmap);
    DeleteDC(g_lyric.buffer_dc);
  }
  if (g_lyric.buffer_bitmap) DeleteObject(g_lyric.buffer_bitmap);
  g_lyric.buffer_dc = nullptr;
  g_lyric.buffer_bitmap = nullptr;
  g_lyric.buffer_old_bitmap = nullptr;
  g_lyric.buffer_bits = nullptr;
  g_lyric.buffer_width = 0;
  g_lyric.buffer_height = 0;
}

bool EnsureLyricBuffer(HWND hwnd, int width, int height) {
  if (g_lyric.buffer_dc && g_lyric.buffer_width == width &&
      g_lyric.buffer_height == height)
    return true;
  ReleaseLyricBuffer();
  BITMAPINFO info = {};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = width;
  info.bmiHeader.biHeight = -height;
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  HDC screen = GetDC(hwnd);
  g_lyric.buffer_dc = CreateCompatibleDC(screen);
  g_lyric.buffer_bitmap = CreateDIBSection(
      screen, &info, DIB_RGB_COLORS, &g_lyric.buffer_bits, nullptr, 0);
  ReleaseDC(hwnd, screen);
  if (!g_lyric.buffer_dc || !g_lyric.buffer_bitmap || !g_lyric.buffer_bits) {
    ReleaseLyricBuffer();
    return false;
  }
  g_lyric.buffer_old_bitmap =
      SelectObject(g_lyric.buffer_dc, g_lyric.buffer_bitmap);
  g_lyric.buffer_width = width;
  g_lyric.buffer_height = height;
  return true;
}

void AddRoundedRectPath(Gdiplus::GraphicsPath& path,
                        const Gdiplus::RectF& rect, float radius) {
  const float diameter = radius * 2.0f;
  path.AddArc(rect.X, rect.Y, diameter, diameter, 180, 90);
  path.AddArc(rect.GetRight() - diameter, rect.Y, diameter, diameter, 270, 90);
  path.AddArc(rect.GetRight() - diameter, rect.GetBottom() - diameter,
              diameter, diameter, 0, 90);
  path.AddArc(rect.X, rect.GetBottom() - diameter, diameter, diameter, 90, 90);
  path.CloseFigure();
}

Gdiplus::Color LyricAccent(BYTE alpha = 255) {
  return Gdiplus::Color(alpha, GetRValue(g_lyric.accent),
                        GetGValue(g_lyric.accent), GetBValue(g_lyric.accent));
}

double RenderedLyricProgress() {
  if (!g_lyric.playing || g_lyric.progress_tick == 0)
    return std::clamp(g_lyric.progress, 0.0, 1.0);
  const double elapsed = static_cast<double>(std::min<ULONGLONG>(
                             GetTickCount64() - g_lyric.progress_tick, 140)) /
                         1000.0;
  return std::clamp(g_lyric.progress + g_lyric.progress_velocity * elapsed,
                    0.0, 1.0);
}

void RenderDesktopLyricWindow(HWND hwnd) {
  if (!hwnd || !IsWindowVisible(hwnd)) return;
  RECT client = {};
  GetClientRect(hwnd, &client);
  const int width = client.right - client.left;
  const int height = client.bottom - client.top;
  if (width <= 0 || height <= 0 || !EnsureLyricBuffer(hwnd, width, height))
    return;
  memset(g_lyric.buffer_bits, 0, static_cast<size_t>(width) * height * 4);
  Gdiplus::Bitmap bitmap(width, height, width * 4,
                         PixelFormat32bppPARGB,
                         static_cast<BYTE*>(g_lyric.buffer_bits));
  Gdiplus::Graphics graphics(&bitmap);
  graphics.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
  graphics.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHighQuality);
  // Layered windows cannot use ClearType safely. Grid-fitted grayscale text
  // stays crisp on both light and dark desktops without colour fringes.
  graphics.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
  const float scale = LyricScale(hwnd);

  if (g_lyric.hover_amount > 0.01) {
    const BYTE panel_alpha = static_cast<BYTE>(142 * g_lyric.hover_amount);
    Gdiplus::GraphicsPath panel;
    AddRoundedRectPath(
        panel,
        Gdiplus::RectF(1.0f * scale, 1.0f * scale, width - 2.0f * scale,
                       height - 2.0f * scale),
        14.0f * scale);
    Gdiplus::SolidBrush panel_brush(Gdiplus::Color(panel_alpha, 20, 24, 31));
    graphics.FillPath(&panel_brush, &panel);
    Gdiplus::Pen panel_border(
        Gdiplus::Color(static_cast<BYTE>(72 * g_lyric.hover_amount), 255, 255, 255),
        1.0f * scale);
    graphics.DrawPath(&panel_border, &panel);
  }

  Gdiplus::FontFamily lyric_family(L"Noto Sans SC");
  Gdiplus::FontFamily fallback_family(L"Microsoft YaHei UI");
  Gdiplus::FontFamily* active_family = lyric_family.IsAvailable()
                                             ? &lyric_family
                                             : &fallback_family;
  Gdiplus::StringFormat format;
  format.SetAlignment(Gdiplus::StringAlignmentCenter);
  format.SetLineAlignment(Gdiplus::StringAlignmentCenter);
  format.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);
  format.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
  const float toolbar_height = 43.0f * scale;
  Gdiplus::RectF title_rect(26.0f * scale, toolbar_height,
                            width - 52.0f * scale, 46.0f * scale);
  Gdiplus::RectF secondary_rect(28.0f * scale, toolbar_height + 43.0f * scale,
                                width - 56.0f * scale, 30.0f * scale);
  Gdiplus::Font title_font(active_family, 28.0f * scale,
                           Gdiplus::FontStyleBold, Gdiplus::UnitPixel);
  Gdiplus::RectF measured;
  graphics.MeasureString(g_lyric.text.c_str(), -1, &title_font,
                         Gdiplus::PointF(0, 0), &format, &measured);
  float highlight_left =
      title_rect.X + (std::max)(0.0f, (title_rect.Width - measured.Width) / 2);
  if (measured.Width > title_rect.Width) {
    const float overflow = measured.Width - title_rect.Width + 18.0f * scale;
    const float scroll_offset = std::round(
        -overflow * static_cast<float>(RenderedLyricProgress()));
    title_rect.X += (std::min)(0.0f, scroll_offset);
    title_rect.Width = measured.Width + 60.0f * scale;
    highlight_left = title_rect.X;
    format.SetAlignment(Gdiplus::StringAlignmentNear);
    format.SetTrimming(Gdiplus::StringTrimmingNone);
  }
  Gdiplus::SolidBrush title_brush(Gdiplus::Color(245, 244, 247, 251));
  Gdiplus::SolidBrush title_shadow(Gdiplus::Color(110, 0, 0, 0));
  Gdiplus::RectF title_shadow_rect = title_rect;
  title_shadow_rect.Offset(0.65f * scale, 0.85f * scale);
  graphics.DrawString(g_lyric.text.c_str(), -1, &title_font,
                      title_shadow_rect, &format, &title_shadow);
  graphics.DrawString(g_lyric.text.c_str(), -1, &title_font, title_rect,
                      &format, &title_brush);
  const float highlight_width = static_cast<float>(
      measured.Width * RenderedLyricProgress());
  graphics.SetClip(Gdiplus::RectF(highlight_left, title_rect.Y,
                                  highlight_width, title_rect.Height));
  Gdiplus::SolidBrush accent_brush(LyricAccent());
  graphics.DrawString(g_lyric.text.c_str(), -1, &title_font, title_rect,
                      &format, &accent_brush);
  graphics.ResetClip();
  if (!g_lyric.secondary.empty()) {
    Gdiplus::StringFormat secondary_format;
    secondary_format.SetAlignment(Gdiplus::StringAlignmentCenter);
    secondary_format.SetLineAlignment(Gdiplus::StringAlignmentCenter);
    secondary_format.SetTrimming(
        Gdiplus::StringTrimmingEllipsisCharacter);
    secondary_format.SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
    Gdiplus::Font secondary_font(active_family, 17.0f * scale,
                                 Gdiplus::FontStyleRegular,
                                 Gdiplus::UnitPixel);
    Gdiplus::SolidBrush secondary_brush(Gdiplus::Color(220, 188, 197, 211));
    Gdiplus::SolidBrush secondary_shadow(Gdiplus::Color(85, 0, 0, 0));
    Gdiplus::RectF secondary_shadow_rect = secondary_rect;
    secondary_shadow_rect.Offset(0.5f * scale, 0.6f * scale);
    graphics.DrawString(g_lyric.secondary.c_str(), -1, &secondary_font,
                        secondary_shadow_rect, &secondary_format,
                        &secondary_shadow);
    graphics.DrawString(g_lyric.secondary.c_str(), -1, &secondary_font,
                        secondary_rect, &secondary_format, &secondary_brush);
  }

  if (g_lyric.hover_amount > 0.02) {
    Gdiplus::FontFamily icon_family(L"Segoe MDL2 Assets");
    Gdiplus::Font icon_font(&icon_family, 16.0f * scale,
                            Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
    const wchar_t* glyphs[4] = {
        L"\xE892", g_lyric.playing ? L"\xE769" : L"\xE768", L"\xE893",
        L"\xE8BB"};
    for (int index = 0; index < 4; ++index) {
      const RECT source = LyricControlRect(hwnd, client, index);
      Gdiplus::RectF button(static_cast<float>(source.left),
                            static_cast<float>(source.top),
                            static_cast<float>(source.right - source.left),
                            static_cast<float>(source.bottom - source.top));
      if (g_lyric.hot_control == index || g_lyric.pressed_control == index) {
        Gdiplus::GraphicsPath button_path;
        AddRoundedRectPath(button_path, button, 9.0f * scale);
        Gdiplus::SolidBrush button_fill(
            index == 1
                ? Gdiplus::Color(static_cast<BYTE>(150 * g_lyric.hover_amount),
                                 GetRValue(g_lyric.accent),
                                 GetGValue(g_lyric.accent),
                                 GetBValue(g_lyric.accent))
                : (g_lyric.dark
                       ? Gdiplus::Color(static_cast<BYTE>(76 * g_lyric.hover_amount), 255, 255, 255)
                       : Gdiplus::Color(static_cast<BYTE>(62 * g_lyric.hover_amount), 36, 48, 65)));
        graphics.FillPath(&button_fill, &button_path);
      }
      Gdiplus::SolidBrush icon_brush(
          index == 1 && g_lyric.hot_control == 1
              ? Gdiplus::Color(245, 255, 255, 255)
              : (g_lyric.dark ? Gdiplus::Color(240, 229, 234, 242)
                              : Gdiplus::Color(235, 71, 82, 99)));
      graphics.DrawString(glyphs[index], -1, &icon_font, button, &format,
                          &icon_brush);
    }
  }

  RECT window_rect = {};
  GetWindowRect(hwnd, &window_rect);
  POINT destination = {window_rect.left, window_rect.top};
  SIZE size = {width, height};
  POINT source = {0, 0};
  BLENDFUNCTION blend = {AC_SRC_OVER, 0, 255, AC_SRC_ALPHA};
  HDC screen = GetDC(nullptr);
  UpdateLayeredWindow(hwnd, screen, &destination, &size, g_lyric.buffer_dc,
                      &source, 0, &blend, ULW_ALPHA);
  ReleaseDC(nullptr, screen);
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
    case WM_NCHITTEST:
      return HTCLIENT;
    case WM_MOUSEMOVE: {
      POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      if (!g_lyric.tracking_mouse) {
        TRACKMOUSEEVENT tracking = {sizeof(TRACKMOUSEEVENT), TME_LEAVE, hwnd, 0};
        TrackMouseEvent(&tracking);
        g_lyric.tracking_mouse = true;
      }
      g_lyric.hovered = true;
      const int hot_control = HitLyricControl(hwnd, point);
      if (hot_control != g_lyric.hot_control) {
        g_lyric.hot_control = hot_control;
        RenderDesktopLyricWindow(hwnd);
      }
      if (g_lyric.drag_pending || g_lyric.dragging) {
        POINT cursor;
        GetCursorPos(&cursor);
        const int dx = cursor.x - g_lyric.drag_start.x;
        const int dy = cursor.y - g_lyric.drag_start.y;
        const int threshold = static_cast<int>(3 * LyricScale(hwnd));
        if (!g_lyric.dragging &&
            (std::abs(dx) >= threshold || std::abs(dy) >= threshold)) {
          g_lyric.dragging = true;
        }
        if (g_lyric.dragging) {
          SetWindowPos(hwnd, HWND_TOPMOST, g_lyric.drag_window.left + dx,
                       g_lyric.drag_window.top + dy, 0, 0,
                       SWP_NOSIZE | SWP_NOACTIVATE);
        }
      }
      return 0;
    }
    case WM_MOUSELEAVE:
      g_lyric.tracking_mouse = false;
      g_lyric.hovered = false;
      g_lyric.hot_control = -1;
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
    case WM_LBUTTONDOWN: {
      SetCapture(hwnd);
      POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      g_lyric.pressed_control = HitLyricControl(hwnd, point);
      if (g_lyric.pressed_control < 0) {
        g_lyric.drag_pending = true;
        g_lyric.dragging = false;
        GetCursorPos(&g_lyric.drag_start);
        GetWindowRect(hwnd, &g_lyric.drag_window);
      }
      RenderDesktopLyricWindow(hwnd);
      return 0;
    }
    case WM_LBUTTONUP: {
      POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      const int action = HitLyricControl(hwnd, point);
      const bool activate = !g_lyric.dragging && action >= 0 &&
                            action == g_lyric.pressed_control;
      ReleaseCapture();
      g_lyric.drag_pending = false;
      g_lyric.dragging = false;
      g_lyric.pressed_control = -1;
      if (activate && action == 0 && g_lyric.owner)
        PostMessage(g_lyric.owner, WM_COMMAND, kPreviousButton, 0);
      if (activate && action == 1 && g_lyric.owner)
        PostMessage(g_lyric.owner, WM_COMMAND, kPlayButton, 0);
      if (activate && action == 2 && g_lyric.owner)
        PostMessage(g_lyric.owner, WM_COMMAND, kNextButton, 0);
      if (activate && action == 3) {
        ShowWindow(hwnd, SW_HIDE);
        KillTimer(hwnd, kDesktopLyricTimer);
        if (g_lyric.owner)
          PostMessage(g_lyric.owner, WM_COMMAND, kDesktopLyricsCloseButton, 0);
      }
      RenderDesktopLyricWindow(hwnd);
      return 0;
    }
    case WM_TIMER: {
      const double target = g_lyric.hovered ? 1.0 : 0.0;
      const double step = g_lyric.hovered ? 0.16 : 0.20;
      const double previous_hover = g_lyric.hover_amount;
      if (g_lyric.hover_amount < target)
        g_lyric.hover_amount = std::min(target, g_lyric.hover_amount + step);
      else if (g_lyric.hover_amount > target)
        g_lyric.hover_amount = std::max(target, g_lyric.hover_amount - step);
      if (g_lyric.playing || previous_hover != g_lyric.hover_amount)
        RenderDesktopLyricWindow(hwnd);
      return 0;
    }
    case WM_ERASEBKGND:
      return 1;
    case WM_PAINT: {
      PAINTSTRUCT paint;
      BeginPaint(hwnd, &paint);
      EndPaint(hwnd, &paint);
      RenderDesktopLyricWindow(hwnd);
      return 0;
    }
    case WM_DPICHANGED: {
      const RECT* suggested = reinterpret_cast<RECT*>(lparam);
      SetWindowPos(hwnd, HWND_TOPMOST, suggested->left, suggested->top,
                   suggested->right - suggested->left,
                   suggested->bottom - suggested->top,
                   SWP_NOACTIVATE);
      ReleaseLyricBuffer();
      RenderDesktopLyricWindow(hwnd);
      return 0;
    }
    case WM_DESTROY:
      KillTimer(hwnd, kDesktopLyricTimer);
      ReleaseLyricBuffer();
      return 0;
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
  if (!g_lyric.gdiplus_token) {
    Gdiplus::GdiplusStartupInput input;
    Gdiplus::GdiplusStartup(&g_lyric.gdiplus_token, &input, nullptr);
    wchar_t executable_path[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, executable_path, MAX_PATH);
    std::wstring font_path(executable_path);
    const size_t slash = font_path.find_last_of(L"\\/");
    if (slash != std::wstring::npos) font_path.resize(slash + 1);
    font_path += L"data\\flutter_assets\\assets\\fonts\\NotoSansSC-Variable.ttf";
    AddFontResourceExW(font_path.c_str(), FR_PRIVATE, nullptr);
  }
  const float scale = static_cast<float>(GetDpiForSystem()) / 96.0f;
  const int width = static_cast<int>(820 * scale);
  const int height = static_cast<int>(132 * scale);
  RECT work_area = {};
  SystemParametersInfoW(SPI_GETWORKAREA, 0, &work_area, 0);
  const int x = work_area.left + (work_area.right - work_area.left - width) / 2;
  const int y = work_area.bottom - height - static_cast<int>(54 * scale);
  g_lyric.window = CreateWindowExW(
      WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_NOACTIVATE,
      kDesktopLyricClass, L"QingTing Desktop Lyrics", WS_POPUP, x, y, width,
      height, nullptr,
      nullptr, GetModuleHandle(nullptr), nullptr);
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
          if (g_lyric.window) RenderDesktopLyricWindow(g_lyric.window);
          result->Success();
          return;
        }
        if (call.method_name() == "showDesktopLyrics") {
          const bool visible = call.arguments() && std::get<bool>(*call.arguments());
          HWND lyric = EnsureDesktopLyricWindow(GetHandle());
          if (lyric) {
            ShowWindow(lyric, visible ? SW_SHOWNOACTIVATE : SW_HIDE);
            if (visible) {
              SetTimer(lyric, kDesktopLyricTimer, kDesktopLyricFrameMs, nullptr);
              RenderDesktopLyricWindow(lyric);
            } else {
              KillTimer(lyric, kDesktopLyricTimer);
            }
          }
          result->Success();
          return;
        }
        if (call.method_name() == "updateDesktopLyrics") {
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto string_value = [&](const char* key) {
              const auto it = args->find(flutter::EncodableValue(key));
              return it == args->end() ? std::string() : std::get<std::string>(it->second);
            };
            const std::wstring next_text = Utf8ToWide(string_value("text"));
            const bool line_changed = next_text != g_lyric.text;
            const double rendered_progress = RenderedLyricProgress();
            g_lyric.text = next_text;
            g_lyric.secondary = Utf8ToWide(string_value("secondary"));
            const auto progress = args->find(flutter::EncodableValue("progress"));
            if (progress != args->end()) {
              double next_progress = g_lyric.progress;
              if (const auto* progress_double =
                      std::get_if<double>(&progress->second)) {
                next_progress = *progress_double;
              } else if (const auto* progress_32 =
                             std::get_if<int32_t>(&progress->second)) {
                next_progress = static_cast<double>(*progress_32);
              } else if (const auto* progress_64 =
                             std::get_if<int64_t>(&progress->second)) {
                next_progress = static_cast<double>(*progress_64);
              }
              // The Flutter position stream updates less often than this
              // native window renders. Repeated method-channel updates can
              // therefore carry the same stale progress and pull a smooth
              // marquee backwards every frame. Keep the native monotonic
              // position for small same-line regressions; a real seek or a
              // new lyric line still replaces it immediately.
              if (!line_changed && g_lyric.playing &&
                  next_progress < rendered_progress &&
                  rendered_progress - next_progress < 0.15) {
                next_progress = rendered_progress;
              }
              const ULONGLONG now = GetTickCount64();
              // Use the velocity of the active timed word from Dart. Limit
              // extrapolation in RenderedLyricProgress so a delayed Flutter
              // update cannot run past the current word or a timing gap.
              const auto velocity_it =
                  args->find(flutter::EncodableValue("velocity"));
              double dart_velocity = 0.0;
              if (velocity_it != args->end()) {
                if (const auto* v =
                        std::get_if<double>(&velocity_it->second)) {
                  dart_velocity = *v;
                }
              }
              g_lyric.progress_velocity =
                  std::clamp(dart_velocity, 0.0, 12.0);
              g_lyric.progress = std::clamp(next_progress, 0.0, 1.0);
              g_lyric.progress_tick = now;
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
          if (g_lyric.window) RenderDesktopLyricWindow(g_lyric.window);
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
  ReleaseLyricBuffer();
  if (g_lyric.gdiplus_token) {
    Gdiplus::GdiplusShutdown(g_lyric.gdiplus_token);
    g_lyric.gdiplus_token = 0;
  }
  g_lyric.owner = nullptr;
  if (taskbar_) { taskbar_->Release(); taskbar_ = nullptr; }
  thumbar_added_ = false;
  for (HICON icon : {previous_icon_, play_icon_, pause_icon_, next_icon_})
    if (icon) DestroyIcon(icon);
  previous_icon_ = play_icon_ = pause_icon_ = next_icon_ = nullptr;
  media_channel_.reset();
}
