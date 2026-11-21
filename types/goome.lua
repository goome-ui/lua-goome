---@meta goome

---@alias goome.Color integer
---@alias goome.Rect {x: integer, y: integer, w: integer, h: integer}
---@alias goome.RectLike goome.Rect|integer[]
---@alias goome.Radii number|number[]|{tl: number?, tr: number?, br: number?, bl: number?}
---@alias goome.Backend "auto"|"wayland"|"gnome"|"portal"|"x11"|"win32"|"macos"|"test"|"offscreen"|integer
---@alias goome.Mode "overlay"|"window"|"offscreen"|integer
---@alias goome.Dir "auto"|"ltr"|"rtl"
---@alias goome.Preset "dark"|"light"|"midnight"|"paper"|"mint"|"high_contrast"|"rose"|integer
---@alias goome.StyleName "bg"|"panel"|"border"|"text"|"text_dim"|"accent"|"accent_text"|"hover"|"active"|"input_bg"|"shadow"|"radius"|"pad"|"gap"|"border_width"|"font_size"|"shadow_blur"|"anim_ms"|"focus"|"select"|"caret"|"link"|"badge"|"toast"|"tooltip"|"danger"|"knob"|"dim"|"check_size"|"check_radius"|"toggle_w"|"toggle_h"|"slider_h"|"slider_track"|"knob_size"|"scroll_w"|"scroll_min"|"item_h"|"menu_item_h"|"tab_h"|"win_title_h"|"app_title_h"|"menubar_h"|"statusbar_h"|"focus_w"|"focus_gap"|"sep_w"|"grip"|"indent"|"plot_w"|"spinner"|"caret_w"|"win_min_w"|"win_min_h"|"pop_gap"|"menu_gap"|"tip_pad_x"|"tip_pad_y"|"tip_x"|"tip_y"|"tip_radius"|"shadow_x"|"shadow_y"|"align"|"heading_size"|"small_size"|"ease"|"hover_ms"|"press_ms"|"popup_ms"|"collapse_ms"|"toast_fade_ms"|integer
---@alias goome.SkinName "button"|"panel"|"input"|"checkbox"|"radio"|"toggle"|"slider_track"|"slider_fill"|"scrollbar"|"tab"|"titlebar"|"tooltip"|"menu"|"popup"|integer
---@alias goome.HasPixels goome.Canvas|goome.Image|goome.Bitmap|goome.Pixels
---@alias goome.Skin goome.Bitmap|{[1]: goome.Bitmap, [2]: number?, [3]: number?, [4]: number?, [5]: number?, bitmap: goome.Bitmap?, l: number?, t: number?, r: number?, b: number?}

---@class goome.Monitor
---@field id integer
---@field name string
---@field area goome.Rect Logical desktop coords.
---@field scale number Real px per logical px.
---@field pw integer Real px.
---@field ph integer Real px.
---@field rotation integer 0, 90, 180 or 270, plus 360 if mirrored. Grabs and canvases already undo it.

---@class goome.Event
---@field type integer One of the event constants (goome.DOWN, goome.KEY and so on).
---@field x number Logical.
---@field y number Logical.
---@field mon integer
---@field button integer 1 left, 2 middle, 3 right.
---@field dy integer Scroll notches, +1 = down.
---@field key integer Lowercase ascii or a goome.K_ constant.
---@field mods integer goome.SHIFT, goome.CTRL, goome.ALT and goome.SUPER added up.
---@field text string The utf-8 that got typed, can be empty.
---@field id integer
---@field msg string The goome.CONTROL line, or the text of a TEXT/PREEDIT event (cut at 63 bytes).
---@field path string? On goome.DROP, the full path of the dropped file.
---@field ime string? On goome.TEXT and goome.PREEDIT, the full utf-8 text.
---@field caret integer? On goome.PREEDIT, the caret byte offset in the text.

---@class goome.WindowState
---@field x number?
---@field y number?
---@field w number?
---@field h number? 0 or nil = fit the content.
---@field open boolean?

---@class goome.Item
---@field x number Where it ended up, logical.
---@field y number
---@field w number
---@field h number
---@field hovered boolean
---@field pressed boolean
---@field held boolean
---@field released boolean
---@field clicked boolean
---@field double_clicked boolean
---@field right_clicked boolean
---@field focused boolean
---@field mx number Pointer, logical.
---@field my number
---@field dx number Moved this frame while held, after the axis lock.
---@field dy number
---@field drag_x number Since the press, after the axis lock.
---@field drag_y number
---@field key integer Key pressed this frame while focused with goome.SHIFT etc added in, 0 = none.

---@class goome.A11yNode
---@field role integer A goome.ROLE_ constant.
---@field parent integer? 1 based index of the parent node.
---@field states integer goome.A11Y_ bits.
---@field focused boolean
---@field checked boolean
---@field disabled boolean
---@field expanded boolean
---@field selected boolean
---@field x number
---@field y number
---@field w number
---@field h number
---@field label string
---@field value string
---@field id integer
---@field num number
---@field min number
---@field max number
---@field caret integer

---@class goome.Opts
---@field title string? Default "goome".
---@field backend goome.Backend? Default auto. The env var GOOME_BACKEND wins.
---@field mode goome.Mode? Default overlay.
---@field state_dir string? The portal token and control fifo live here. nil = neither.
---@field no_capture boolean? Overlay only, never asks for screen access.
---@field capture_fps integer? gnome/portal streams, 0 = 5.
---@field hide_self boolean? Keep our overlay out of grabs where the os lets us.
---@field test_frames string? goome.TEST only, env GOOME_TEST_FRAMES.
---@field test_script string? goome.TEST only, env GOOME_TEST_SCRIPT.
---@field test_shots string? goome.TEST only, env GOOME_TEST_SHOTS.
---@field width integer? Window or offscreen size, logical. 0 = 960x640.
---@field height integer?
---@field min_width integer? Window only, 0 = none.
---@field min_height integer? Window only, 0 = none.
---@field window_flags integer? goome.WINDOW_ flags added up.
---@field scale number? Offscreen only, 0 = 1.

---@class goome.AppOpts
---@field title string?
---@field width integer? Default 960.
---@field height integer? Default 640.
---@field flags integer? goome.APP_ flags for ui:app.
---@field fps integer? Default 60.
---@field idle_ms integer? How long to wait for events when nothing is animating. Default 500.
---@field light boolean? Start with the light theme.

---@class goome.Goome
local Goome = {}

---Closes it and everything made from it (uis, canvases). Safe to call twice. Also runs on `<close>` and when it gets garbage collected.
function Goome:close() end

---@return boolean
function Goome:closed() end

---The last error message on this handle.
---@return string
function Goome:error() end

---@return string
function Goome:backend_name() end

---Bits of what this backend can do, goome.CAP_ constants.
---@return integer
function Goome:caps() end

---@param cap integer A goome.CAP_ constant.
---@return boolean
function Goome:can(cap) end

---@return goome.Monitor[]|nil monitors
---@return string? err
---@return integer? code
function Goome:monitors() end

---Grabs a monitor. The image is only good until the next grab of that monitor, `copy()` it to keep it.
---@param mon integer? Default 0.
---@param rect goome.RectLike? Part of the monitor, in its own coordinates. Default the whole monitor. Can also be passed as x, y, w, h.
---@return goome.Image|nil
---@return string? err
---@return integer? code
function Goome:capture(mon, rect) end

---Like capture, but keeps retrying while the backend says "try again" (goome.EAGAIN).
---@param mon integer? Default 0.
---@param rect goome.RectLike? Part of the monitor. Can also be passed as x, y, w, h, then timeout.
---@param timeout_ms integer? How long to keep trying. Default 5000.
---@return goome.Image|nil
---@return string? err
---@return integer? code
function Goome:capture_wait(mon, rect, timeout_ms) end

---How see-through our overlay is at x,y (logical). Use it to mask the overlay out of a grab that has_self.
---@param x number
---@param y number
---@return integer
function Goome:alpha_at(x, y) end

---Starts a frame. nil means nothing to draw on, skip the frame.
---@param mon integer? Default 0.
---@return goome.Canvas|nil
function Goome:begin(mon) end

---Sends the frame. Only the hit rects (plus any added with `canvas:hit`) take clicks in overlay mode.
---@param canvas goome.Canvas
---@param hits goome.RectLike[]? Hit rects, each {x, y, w, h} or {x = , y = , w = , h = }.
---@return true|nil
---@return string? err
---@return integer? code
function Goome:finish(canvas, hits) end

---Waits up to timeout_ms for one event. nil means nothing came.
---@param timeout_ms integer? Default 0.
---@return goome.Event|nil
---@return string? err
---@return integer? code
function Goome:poll(timeout_ms) end

---For loop over events. Waits up to timeout_ms for the first one, after that it only hands out what's already queued.
---@param timeout_ms integer? Default 0.
---@return fun(): goome.Event?
function Goome:events(timeout_ms) end

---Pointer position anywhere on the screen, logical. nil if the backend can't say.
---@return number? x
---@return number? y
---@return integer? buttons
function Goome:pointer() end

---@param on boolean? Default true.
---@return true|nil
---@return string? err
---@return integer? code
function Goome:keyboard(on) end

---Overlay: focus + pointer capture until you call it with false. Window: drags keep going outside it.
---@param on boolean? Default true.
---@return true|nil
---@return string? err
---@return integer? code
function Goome:grab(on) end

---@return boolean
function Goome:grabbed() end

---Gets you a goome.HOTKEY event with this id when the combo is pressed.
---@param combo string Like "alt+h". See goome.parse_combo.
---@param id integer? Default 1.
---@return true|nil
---@return string? err
---@return integer? code
function Goome:hotkey(combo, id) end

---Path of the control fifo (see goome.send), nil if there isn't one.
---@return string?
function Goome:control_path() end

---One of goome.MODE_OVERLAY, MODE_WINDOW, MODE_OFFSCREEN.
---@return integer
function Goome:mode() end

---@param title string
---@return true|nil
---@return string? err
---@return integer? code
function Goome:window_title(title) end

---@param w integer Logical client size.
---@param h integer
---@return true|nil
---@return string? err
---@return integer? code
function Goome:window_size(w, h) end

---Call with x, y to move it, without arguments to read it. Not supported where the os won't say (wayland).
---@param x integer?
---@param y integer?
---@return integer? x
---@return integer? y
---@return string? err
---@return integer? code
function Goome:window_pos(x, y) end

---Sets the state with an argument (goome.STATE_ constant), reads it without.
---@param state integer?
---@return integer|true|nil
---@return string? err
---@return integer? code
function Goome:window_state(state) end

---Native move or resize, from the press that's happening right now.
---@param edges integer? 0 or nil = move, or goome.EDGE_ bits added up to resize.
---@return true|nil
---@return string? err
---@return integer? code
function Goome:window_drag(edges) end

---@param on boolean? Default true.
---@return true|nil
---@return string? err
---@return integer? code
function Goome:window_show(on) end

---Sets the cursor with an argument (goome.CURSOR_ constant). Without one it gives the last one asked for.
---@param shape integer?
---@return integer|true|nil
---@return string? err
---@return integer? code
function Goome:cursor(shape) end

---Sets the clipboard with a string, reads it without. Can block around 250ms on x11/wayland.
---@param text string?
---@return string|true|nil
---@return string? err
---@return integer? code
function Goome:clipboard(text) end

---Full path of the last goome.DROP, good until the next poll.
---@return string?
function Goome:drop_path() end

---Full utf-8 of the last goome.TEXT / goome.PREEDIT, good until the next poll.
---@return string
function Goome:event_text() end

---Byte offset of the caret in the last preedit text.
---@return integer
function Goome:preedit_cursor() end

---Turns the ime on or off.
---@param on boolean? Default true.
---@param caret goome.RectLike? Where the candidate window goes, logical.
---@return true|nil
---@return string? err
---@return integer? code
function Goome:text_input(on, caret) end

---Queues a goome.TEXT event.
---@param text string?
---@return true|nil
---@return string? err
---@return integer? code
function Goome:push_ime(text) end

---Queues a goome.PREEDIT event.
---@param text string?
---@param caret integer? Caret byte offset. Default 0.
---@return true|nil
---@return string? err
---@return integer? code
function Goome:push_preedit(text, caret) end

---Queues an event, any mode. Pass a table with the event fields or a type with an optional fields table.
---@param ev table|integer
---@param fields table?
---@return true|nil
---@return string? err
---@return integer? code
function Goome:push(ev, fields) end

---Queues one key event per character of the text.
---@param text string
function Goome:push_text(text) end

---Queues a move, a press and a release at x,y.
---@param x number
---@param y number
---@param button integer? Default 1.
function Goome:push_click(x, y, button) end

---Offscreen only.
---@param w integer
---@param h integer
---@param scale number? 0 or nil = 1.
---@return true|nil
---@return string? err
---@return integer? code
function Goome:resize(w, h, scale) end

---The last frame `finish` sent, premultiplied argb. Good until the next `begin`.
---@return goome.Image|nil
---@return string? err
---@return integer? code
function Goome:last_frame() end

---True if x,y is in the hit rects of the last `finish`.
---@param x number
---@param y number
---@return boolean
function Goome:hit(x, y) end

---The real px rect that changed since the last call, nil = nothing. The first one after open/resize is the whole frame.
---@return goome.Rect|nil
---@return string? err
---@return integer? code
function Goome:frame_dirty() end

---Copies the last frame, or part of it. With no destination you get the bytes as a string (4 per px), with a lightuserdata pointer and a stride in bytes it writes there.
---@param format integer? A goome.FMT_ constant. Default goome.FMT_BGRA_PREMUL. The non premul ones unpremultiply.
---@param rect goome.RectLike? Real px. Default the whole frame.
---@param dst lightuserdata? Where to write.
---@param stride integer? Row size of dst in bytes, needed with dst.
---@param at_rect boolean? With dst: true puts the rect's top left at dst instead of the frame's top left.
---@return string|true|nil
---@return string? err
---@return integer? code
function Goome:frame_copy(format, rect, dst, stride, at_rect) end

---The ui kit for this handle.
---@return goome.Ui|nil
---@return string? err
---@return integer? code
function Goome:ui() end

---@class goome.Canvas
---@field w integer Real px.
---@field h integer
---@field stride integer In pixels.
---@field ox number Logical spot of the first pixel.
---@field oy number
---@field scale number Real px per logical px.
---@field mon integer
---@field dx0 integer Drawn since the clear.
---@field dy0 integer
---@field dx1 integer
---@field dy1 integer
---@field cx0 integer What the clear wiped.
---@field cy0 integer
---@field cx1 integer
---@field cy1 integer
---@field kx0 integer Clip in real px, drawing never leaves it.
---@field ky0 integer
---@field kx1 integer
---@field ky1 integer
---@field nclip integer
local Canvas = {}

---False once it got handed back with `finish`.
---@return boolean
function Canvas:valid() end

---Wipes it.
function Canvas:clear() end

---Drawing uses logical coords, the canvas scales them. Colors are 0xAARRGGBB.
---@param x number
---@param y number
---@param w number
---@param h number
---@param color goome.Color
function Canvas:rect(x, y, w, h, color) end

---@param x number
---@param y number
---@param w number
---@param h number
---@param radius number
---@param color goome.Color
function Canvas:round_rect(x, y, w, h, radius, color) end

---Rect outline.
---@param x number
---@param y number
---@param w number
---@param h number
---@param width number Line width.
---@param color goome.Color
function Canvas:frame(x, y, w, h, width, color) end

---@param x0 number
---@param y0 number
---@param x1 number
---@param y1 number
---@param width number
---@param color goome.Color
function Canvas:line(x0, y0, x1, y1, width, color) end

---@param x0 number
---@param y0 number
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color goome.Color
function Canvas:triangle(x0, y0, x1, y1, x2, y2, color) end

---Draws raw plain argb pixels scaled to x,y,w,h.
---@param x number
---@param y number
---@param w number
---@param h number
---@param pixels goome.HasPixels|integer[]|string Pixels with stride == width, a list of argb numbers, or a string of BGRA bytes.
---@param iw integer Pixel width.
---@param ih integer Pixel height.
function Canvas:image(x, y, w, h, pixels, iw, ih) end

---Clears an area to see-through.
---@param x number
---@param y number
---@param w number
---@param h number
function Canvas:erase(x, y, w, h) end

---Draws text with the built in font. Returns its width.
---@param x number
---@param y number
---@param text string
---@param color goome.Color? Default white.
---@param big boolean? The bigger built in size.
---@return number width
function Canvas:text(x, y, text, color, big) end

---@param text string
---@param big boolean?
---@return number
function Canvas:text_width(text, big) end

---Draws another canvas on this one.
---@param src goome.Canvas
---@param alpha number? Default 1.
---@param dx number? Default 0.
---@param dy number? Default 0.
function Canvas:blit(src, alpha, dx, dy) end

---Snaps to whole px, 16 deep, `begin` resets it.
---@param x number
---@param y number
---@param w number
---@param h number
function Canvas:clip_push(x, y, w, h) end

function Canvas:clip_pop() end

---Rect with a radius per corner.
---@param x number
---@param y number
---@param w number
---@param h number
---@param radii goome.Radii
---@param color goome.Color
function Canvas:rrect(x, y, w, h, radii, color) end

---@param x number
---@param y number
---@param w number
---@param h number
---@param radii goome.Radii
---@param width number
---@param color goome.Color
function Canvas:rrect_line(x, y, w, h, radii, width, color) end

---@param x number
---@param y number
---@param w number
---@param h number
---@param radii goome.Radii
---@param from goome.Color
---@param to goome.Color
---@param sideways boolean? Left to right instead of top to bottom.
function Canvas:rrect_grad(x, y, w, h, radii, from, to, sideways) end

---Blur works like css box-shadow.
---@param x number
---@param y number
---@param w number
---@param h number
---@param radius number
---@param blur number
---@param color goome.Color
function Canvas:shadow(x, y, w, h, radius, blur, color) end

---@param cx number
---@param cy number
---@param r number
---@param color goome.Color
function Canvas:circle(cx, cy, r, color) end

---@param cx number
---@param cy number
---@param r number Middle of the stroke.
---@param width number
---@param color goome.Color
function Canvas:ring(cx, cy, r, width, color) end

---Radians, 0 = 3 oclock, clockwise, round caps.
---@param cx number
---@param cy number
---@param r number
---@param width number
---@param a0 number
---@param a1 number
---@param color goome.Color
function Canvas:arc(cx, cy, r, width, a0, a1, color) end

---Nonzero fill.
---@param points number[]|number[][] x,y pairs, flat or as {x, y} tables.
---@param color goome.Color
function Canvas:poly(points, color) end

---@param bitmap goome.Bitmap
---@param x number
---@param y number
---@param w number
---@param h number
---@param radii goome.Radii? Round corners.
---@param tint goome.Color? Default white.
function Canvas:bitmap(bitmap, x, y, w, h, radii, tint) end

---Draws a piece of the bitmap.
---@param bitmap goome.Bitmap
---@param sx integer Source rect in bitmap px.
---@param sy integer
---@param sw integer
---@param sh integer
---@param x number Where it goes, logical.
---@param y number
---@param w number
---@param h number
---@param tint goome.Color? Default white.
function Canvas:bitmap_part(bitmap, sx, sy, sw, sh, x, y, w, h, tint) end

---Nine patch. The border sizes are in bitmap px.
---@param bitmap goome.Bitmap
---@param x number
---@param y number
---@param w number
---@param h number
---@param l number Left border.
---@param t number? Top. Default l.
---@param r number? Right. Default l.
---@param b number? Bottom. Default l.
function Canvas:bitmap_nine(bitmap, x, y, w, h, l, t, r, b) end

---Text with a loaded font. y is the top. Returns its width.
---@param font goome.Font|nil nil = the built in font.
---@param size number
---@param x number
---@param y number
---@param text string
---@param color goome.Color? Default white.
---@return number width
function Canvas:font_text(font, size, x, y, text, color) end

---Marks a part as changed for frame_dirty. No rect = everything.
---@param rect goome.RectLike?
function Canvas:damage(rect) end

---Adds a click area for `finish`.
---@param x number
---@param y number
---@param w number
---@param h number
function Canvas:hit(x, y, w, h) end

---Gives access to the raw pixels.
---@return goome.Pixels
function Canvas:pixels() end

---@param x integer
---@param y integer
---@return integer argb
function Canvas:pixel(x, y) end

---@param x integer
---@param y integer
---@param argb goome.Color
function Canvas:set_pixel(x, y, argb) end

---FNV hash of the pixels, handy in tests.
---@param w integer? Default the canvas width.
---@param h integer? Default the canvas height.
---@return integer
function Canvas:hash(w, h) end

---Raw pointer to the pixels.
---@return lightuserdata
function Canvas:ptr() end

---Pixels as a string, 4 bytes each.
---@return string
function Canvas:bytes() end

---Writes a ppm file.
---@param path string
---@return true|nil
---@return string? err
---@return integer? code
function Canvas:save_ppm(path) end

---A grab or frame. Only good until the next grab of that monitor (or the next `begin` for a frame).
---@class goome.Image
---@field w integer Real px.
---@field h integer
---@field stride integer In pixels.
---@field mon integer
---@field area goome.Rect
---@field has_self boolean Our overlay is in it, mask with goome:alpha_at.
---@field has_cursor boolean The mouse got baked in at `cursor` (logical).
---@field cursor goome.Rect
---@field fresh boolean False once it's gone stale.
local Image = {}

---Makes a bitmap you can keep.
---@return goome.Bitmap
function Image:copy() end

---@return goome.Pixels
function Image:pixels() end

---@param x integer
---@param y integer
---@return integer argb
function Image:pixel(x, y) end

---@param w integer? Default the image width.
---@param h integer? Default the image height.
---@return integer
function Image:hash(w, h) end

---@return lightuserdata
function Image:ptr() end

---@return string
function Image:bytes() end

---@param path string
---@return true|nil
---@return string? err
---@return integer? code
function Image:save_ppm(path) end

---Indexable view of pixels. `px[i]` is 0 based, `#px` is h * stride.
---@class goome.Pixels
---@field w integer
---@field h integer
---@field stride integer
---@field [integer] integer
local Pixels = {}

---@param x integer
---@param y integer
---@return integer argb
function Pixels:get(x, y) end

---@param x integer
---@param y integer
---@param argb goome.Color
function Pixels:set(x, y, argb) end

---@param w integer?
---@param h integer?
---@return integer
function Pixels:hash(w, h) end

---@return lightuserdata
function Pixels:ptr() end

---@return string
function Pixels:bytes() end

---Sets every pixel.
---@param argb goome.Color? Default 0.
function Pixels:fill(argb) end

---@param path string
---@return true|nil
---@return string? err
---@return integer? code
function Pixels:save_ppm(path) end

---Premultiplied argb pixels. Also closes on `<close>`.
---@class goome.Bitmap
---@field w integer
---@field h integer
---@field stride integer
---@field owned boolean
---@field closed boolean
local Bitmap = {}

---Frees it. Safe to call twice.
function Bitmap:close() end

---@return goome.Pixels
function Bitmap:pixels() end

---@param x integer
---@param y integer
---@return integer argb
function Bitmap:pixel(x, y) end

---@param x integer
---@param y integer
---@param argb goome.Color
function Bitmap:set_pixel(x, y, argb) end

---@param w integer?
---@param h integer?
---@return integer
function Bitmap:hash(w, h) end

---@return lightuserdata
function Bitmap:ptr() end

---@return string
function Bitmap:bytes() end

---@param path string
---@return true|nil
---@return string? err
---@return integer? code
function Bitmap:save_ppm(path) end

---.ttf, .otf or .ttc. Also closes on `<close>`.
---@class goome.Font
---@field closed boolean
local Font = {}

---Frees it. Safe to call twice.
function Font:close() end

---Width and height of the text at that size.
---@param text string
---@param size number
---@return number width
---@return number height
function Font:measure(text, size) end

---@param text string
---@param size number
---@return number
function Font:width(text, size) end

---@param size number
---@return number
function Font:line_height(size) end

---Tried in order for chars this font doesn't have. goome.font_system adds the emoji font by itself. Returns self, up to 8 fallbacks.
---@param fallback goome.Font
---@return goome.Font self
function Font:fallback(fallback) end

---Every setting is a field, read or write: color fields are goome.Color, sizes are numbers, `font*` are fonts and `skin_*` are skins.
---@class goome.Theme
---@field bg goome.Color
---@field panel goome.Color
---@field border goome.Color
---@field text goome.Color
---@field text_dim goome.Color
---@field accent goome.Color
---@field accent_text goome.Color
---@field hover goome.Color
---@field active goome.Color
---@field input_bg goome.Color
---@field shadow goome.Color
---@field radius number
---@field pad number
---@field gap number
---@field border_width number
---@field font_size number
---@field shadow_blur number
---@field anim_ms number
---@field font goome.Font|lightuserdata|nil nil = built in. `g:ui()` puts the system font here.
---@field skin_button goome.Skin?
---@field skin_panel goome.Skin?
---@field skin_input goome.Skin?
---@field icon_tint goome.Color
---@field skin_checkbox goome.Skin?
---@field skin_radio goome.Skin?
---@field skin_toggle goome.Skin?
---@field skin_slider goome.Skin?
---@field skin_slider_fill goome.Skin?
---@field skin_scrollbar goome.Skin?
---@field skin_tab goome.Skin?
---@field skin_titlebar goome.Skin?
---@field skin_tooltip goome.Skin?
---@field skin_menu goome.Skin?
---@field skin_popup goome.Skin?
---@field focus goome.Color
---@field select goome.Color
---@field caret goome.Color
---@field link goome.Color
---@field badge goome.Color
---@field toast goome.Color
---@field tooltip goome.Color
---@field danger goome.Color
---@field knob goome.Color
---@field dim goome.Color
---@field check_size number
---@field check_radius number
---@field toggle_w number
---@field toggle_h number
---@field slider_h number
---@field slider_track number
---@field knob_size number
---@field scroll_w number
---@field scroll_min number
---@field item_h number
---@field menu_item_h number
---@field tab_h number
---@field win_title_h number
---@field app_title_h number
---@field menubar_h number
---@field statusbar_h number
---@field focus_w number
---@field focus_gap number
---@field sep_w number
---@field grip number
---@field indent number
---@field plot_w number
---@field spinner number
---@field caret_w number
---@field win_min_w number
---@field win_min_h number
---@field pop_gap number
---@field menu_gap number
---@field tip_pad_x number
---@field tip_pad_y number
---@field tip_x number
---@field tip_y number
---@field tip_radius number
---@field shadow_x number
---@field shadow_y number
---@field align number A goome.ALIGN_ constant.
---@field heading_size number
---@field small_size number
---@field ease number A goome.EASE_ constant.
---@field hover_ms number
---@field press_ms number
---@field popup_ms number
---@field collapse_ms number
---@field toast_fade_ms number
---@field font_heading goome.Font|lightuserdata|nil
---@field font_mono goome.Font|lightuserdata|nil
---@field font_small goome.Font|lightuserdata|nil
local Theme = {}

---Back to the dark colors. Leaves the font alone.
function Theme:dark() end

function Theme:light() end

---Builds a whole theme from one accent color.
---@param accent goome.Color
---@param dark boolean? Default true.
---@param radius number? Default 10.
function Theme:make(accent, dark, radius) end

---@param preset goome.Preset
---@return true|nil
---@return string? err
---@return integer? code
function Theme:preset(preset) end

---Reads an icon bitmap, or sets it when you pass one (nil clears it).
---@param icon integer A goome.ICON_ constant.
---@param bitmap goome.Bitmap?
---@return goome.Bitmap|nil
function Theme:icon(icon, bitmap) end

---A separate theme with the same values.
---@return goome.Theme
function Theme:copy() end

---Names of every field.
---@return string[]
function Theme:fields() end

---Keyboard and mouse behavior of a ui, every setting is a field.
---@class goome.Config
---@field tip_delay_ms integer
---@field dbl_click_ms integer
---@field dbl_click_px integer
---@field drag_px integer
---@field repeat_delay_ms integer
---@field repeat_ms integer
---@field blink_ms integer
---@field menu_delay_ms integer
---@field toast_ms integer
---@field scroll_lines number
---@field raise_on_click boolean
---@field esc_closes boolean
---@field tab_nav boolean
---@field focus_on_mouse boolean
---@field mask string?
---@field ease (fun(t: number): number)? Your own curve for goome.EASE_CUSTOM.
local Config = {}

---Reads the cursor shape used for a slot, sets it when you pass a shape.
---@param slot integer A goome.CUR_ constant.
---@param shape integer? A goome.CURSOR_ constant.
---@return integer shape
function Config:cursor(slot, shape) end

---The key combos bound to an action, as a list of {key, mods}.
---@param action integer A goome.ACT_ constant.
---@return integer[][]
function Config:keys(action) end

---Back to the defaults.
function Config:reset() end

---From goome.pacer(). Gives you the wait for a frame loop.
---@class goome.Pacer
local Pacer = {}

---How many ms until the next frame is due, 0 if it's due now. Use it as the poll timeout. If you fall way behind it doesn't catch up, it restarts from now.
---@param fps integer? Default the pacer's fps.
---@return integer
function Pacer:wait(fps) end

---n numbers kept per id, from ui:store. Index from 1.
---@class goome.Store
---@field [integer] number
local Store = {}

---The immediate mode ui kit. Widgets use their label as the id, push_id when you repeat one.
---Widgets that edit a value take the current one and give back the new one plus whether it changed.
---@class goome.Ui
local Ui = {}

---Frees it. Safe to call twice.
function Ui:close() end

---@return boolean
function Ui:closed() end

---Hands the ui an event.
---@param ev goome.Event
---@return boolean used True if the ui used it.
function Ui:feed(ev) end

---Starts a frame. nil means nothing to draw on, skip the frame.
---@param mon integer? Default 0.
---@return goome.Canvas|nil
function Ui:begin(mon) end

---Sends the frame with every widgets hit area.
function Ui:finish() end

---Adds your own hit area, for stuff you drew straight on the canvas.
---@param x number
---@param y number
---@param w number
---@param h number
function Ui:hit(x, y, w, h) end

---True while something still moves, draw again soon.
---@return boolean
function Ui:animating() end

---goome.WANT_ bits, good after `feed` and `finish`.
---@return integer
function Ui:wants() end

---@return boolean
function Ui:wants_mouse() end

---@return boolean
function Ui:wants_keyboard() end

---What the ui takes from the os by itself. Default both, 0 = the app does it.
---@param wants integer goome.WANT_ bits.
function Ui:auto_grab(wants) end

---Draggable window. Pass a table with x, y, w, h and open, it gets written back with where the window ended up. Always call `window_end`.
---@param title string
---@param state goome.WindowState
---@param flags integer? goome.WIN_ flags. Default goome.WIN_MOVE + goome.WIN_COLLAPSE.
---@return boolean
function Ui:window(title, state, flags) end

function Ui:window_end() end

---Puts the next cols widgets side by side, sharing the width.
---@param cols integer
function Ui:row(cols) end

---Puts the next widget right of the last one.
function Ui:same_line() end

---Adds a gap.
---@param px number
function Ui:space(px) end

---Draws a line.
function Ui:separator() end

---Width of the next widget, 0 = fill.
---@param w number? Default 0.
function Ui:width(w) end

---@param text string|number|boolean
function Ui:label(text) end

---@param text string
function Ui:heading(text) end

---@param text string
function Ui:wrapped(text) end

---@param label string
---@return boolean clicked
function Ui:button(label) end

---@param id string
---@param bitmap goome.Bitmap
---@param w number
---@param h number
---@return boolean clicked
function Ui:image_button(id, bitmap, w, h) end

---@param bitmap goome.Bitmap
---@param w number
---@param h number
---@param radius number? Default 0.
function Ui:image(bitmap, w, h, radius) end

---@param label string
---@param value boolean
---@return boolean value
---@return boolean changed
function Ui:checkbox(label, value) end

---@param label string
---@param value boolean
---@return boolean value
---@return boolean changed
function Ui:toggle(label, value) end

---One radio button, `value` is what it stands for.
---@param label string
---@param selected integer The currently selected value.
---@param value integer What this button selects.
---@return integer selected
---@return boolean changed
function Ui:radio(label, selected, value) end

---@param label string
---@param value number
---@param min number? Default 0.
---@param max number? Default 1.
---@param fmt string? Format for the shown value.
---@return number value
---@return boolean changed
function Ui:slider(label, value, min, max, fmt) end

---@param label string
---@param value integer
---@param min integer? Default 0.
---@param max integer? Default 100.
---@return integer value
---@return boolean changed
function Ui:slider_int(label, value, min, max) end

---@param label string
---@param text string?
---@param cap integer? Max bytes, default 256.
---@return string text
---@return boolean changed
function Ui:input(label, text, cap) end

---Input with flags and a hint.
---@param label string
---@param text string?
---@param flags integer? goome.INPUT_ flags added up.
---@param hint string? Grey text shown while empty.
---@param cap integer? Max bytes, default 256.
---@return string text
---@return boolean changed
function Ui:input_ex(label, text, flags, hint, cap) end

---An input with goome.INPUT_PASSWORD already on.
---@param label string
---@param text string?
---@param hint string?
---@param flags integer? More goome.INPUT_ flags.
---@param cap integer? Max bytes, default 256.
---@return string text
---@return boolean changed
function Ui:password(label, text, hint, flags, cap) end

---@param label string
---@param selected integer? 1 based, default 1.
---@param items string[]
---@return integer selected
---@return boolean changed
function Ui:combo(label, selected, items) end

---A full width row, true when clicked. In a scroll area that's a list box.
---@param label string
---@param selected boolean
---@return boolean clicked
function Ui:selectable(label, selected) end

---@param id string
---@param names string[]
---@param selected integer? 1 based, default 1.
---@return integer selected
---@return boolean changed
function Ui:tabs(id, names, selected) end

---Header that opens and closes the stuff under it. Pass your own open state to keep it, it comes back as the second result.
---@param label string
---@param open boolean?
---@return boolean open
---@return boolean? open_value The value to keep, when you passed `open`.
function Ui:collapsing(label, open) end

---@param frac number 0 to 1.
---@param text string?
function Ui:progress(frac, text) end

---Color picker.
---@param label string
---@param argb goome.Color
---@return goome.Color argb
---@return boolean changed
function Ui:color(label, argb) end

---For the widget right before it.
---@param text string
function Ui:tooltip(text) end

---The widget right before it.
---@return boolean
function Ui:hovered() end

---Scroll area of height h, always call `scroll_end`.
---@param id string
---@param h number? Height, default 0.
---@return boolean
function Ui:scroll(id, h) end

function Ui:scroll_end() end

---Use it for the same labels in a loop, push the index first.
---@param id string|number
function Ui:push_id(id) end

function Ui:pop_id() end

---Root panel filling monitor 0, after `begin`. Call `app_end` after it.
---@param title string?
---@param flags integer? goome.APP_ flags.
---@return boolean
function Ui:app(title, flags) end

function Ui:app_end() end

---@return boolean
function Ui:menubar() end

function Ui:menubar_end() end

---True = open, nest for submenus.
---@param label string
---@return boolean
function Ui:menu(label) end

function Ui:menu_end() end

---True = clicked. `checked` shows a check mark and comes back as a second result.
---@param label string
---@param shortcut string? Shown next to the label.
---@param checked boolean?
---@return boolean clicked
---@return boolean? checked
function Ui:menu_item(label, shortcut, checked) end

function Ui:menu_separator() end

---Right click on the widget before it (or empty space) opens it. Call `context_end` when it returned true.
---@param id string
---@return boolean
function Ui:context(id) end

function Ui:context_end() end

---@param id string
function Ui:popup_open(id) end

---@param id string
---@return boolean open
function Ui:popup(id) end

function Ui:popup_end() end

---Closes the innermost open popup, menu or modal.
function Ui:popup_close() end

---Centered, dims the rest, esc closes. Call `modal_end` when it returned true. Pass your own open state to keep it, it comes back as the second result.
---@param title string
---@param open boolean?
---@return boolean open
---@return boolean? open_value The value to keep, when you passed `open`.
function Ui:modal(title, open) end

function Ui:modal_end() end

---@param text string
---@param ms integer? Default 2500.
function Ui:toast(text, ms) end

---Needs goome.APP_STATUSBAR.
---@param text string
function Ui:statusbar(text) end

---The widget right before it has keyboard focus.
---@return boolean
function Ui:focused() end

---Focus goes to the next widget.
function Ui:set_focus() end

---Multiline editor, pass the current text every frame and keep what comes back.
---@param id string
---@param text string?
---@param h number? Default 0.
---@param flags integer? goome.EDIT_ flags added up.
---@param cap integer? Max bytes.
---@return string text
---@return boolean changed
function Ui:text_edit(id, text, h, flags, cap) end

---Always call `table_end`.
---@param id string
---@param cols integer
---@param h number? Default 0.
---@param flags integer? goome.TABLE_ flags added up.
---@return boolean
function Ui:table(id, cols, h, flags) end

---Call it for each column right after `table`.
---@param name string
---@param width number? 0 = share the rest.
function Ui:table_column(name, width) end

---Call it after the columns. goome doesn't sort your data, you do.
---@param col integer? 1 based sorted column.
---@param desc boolean? Sorted descending.
---@return boolean changed True on the frame the sort changed.
---@return integer col
---@return boolean desc
function Ui:table_sort(col, desc) end

function Ui:table_row() end

---Next cell.
function Ui:table_next() end

function Ui:table_end() end

---True = open, then `tree_end`. Pass your own open state to keep it, it comes back as the second result.
---@param label string
---@param open boolean?
---@return boolean open
---@return boolean? open_value The value to keep, when you passed `open`.
function Ui:tree(label, open) end

function Ui:tree_end() end

---In a scroll area, only draw first..last. Both 1 based.
---@param count integer
---@param row_h number? Default 0.
---@return integer first
---@return integer last
function Ui:list_clip(count, row_h) end

---@param label string
---@param value number
---@param speed number? Default 1.
---@param min number? Default 0.
---@param max number? Default 0.
---@param fmt string?
---@return number value
---@return boolean changed
function Ui:drag_float(label, value, speed, min, max, fmt) end

---@param label string
---@param value integer
---@param speed number? Default 1.
---@param min integer? Default 0.
---@param max integer? Default 0.
---@return integer value
---@return boolean changed
function Ui:drag_int(label, value, speed, min, max) end

---@param label string
---@param value number
---@param step number? Default 1.
---@param fmt string?
---@return number value
---@return boolean changed
function Ui:number(label, value, step, fmt) end

---@param label string
---@param values number[]
---@param min number? Default the lowest value.
---@param max number? Default the highest value.
---@param h number? Default 60.
function Ui:plot_lines(label, values, min, max, h) end

---@param label string
---@param values number[]
---@param min number? Default the lowest value.
---@param max number? Default the highest value.
---@param h number? Default 60.
function Ui:plot_bars(label, values, min, max, h) end

---Split pane. Returns whether it's showing and the new fraction. Then `split_next` for the second pane and `split_end`.
---@param id string
---@param frac number? Default 0.5.
---@param vertical boolean?
---@return boolean
---@return number frac
function Ui:split(id, frac, vertical) end

function Ui:split_next() end

function Ui:split_end() end

---The widget before it can be dragged.
---@param type string
---@param data string
---@return boolean
function Ui:drag_source(type, data) end

---The widget before it takes drops of that type. Gives the dropped bytes, or nil if nothing dropped this frame.
---@param type string
---@param cap integer? Max bytes, default 4096.
---@return string?
function Ui:drop_target(type, cap) end

---@param size number? Default 16.
function Ui:spinner(size) end

---@param text string
---@return boolean clicked
function Ui:link(text) end

---@param text string
---@param argb goome.Color? Default the theme's badge color.
function Ui:badge(text, argb) end

---Next widget goes at x,y from the content top left (scroll included), the flow doesn't move.
---@param x number
---@param y number
function Ui:pos(x, y) end

---Next widget size, 0 = its own size for that side.
---@param w number? Default 0.
---@param h number? Default 0.
function Ui:size(w, h) end

---Pushes a color setting until popped.
---@param what goome.StyleName A goome.S_ constant or its name.
---@param argb goome.Color
function Ui:push_color(what, argb) end

---Pushes a number setting (goome.S_RADIUS and the other numbers) until popped.
---@param what goome.StyleName
---@param value number
function Ui:push_num(what, value) end

---Per corner radii, beats the radius setting until popped.
---@param radii goome.Radii
function Ui:push_radii(radii) end

---nil = built in.
---@param font goome.Font?
function Ui:push_font(font) end

---@param kind goome.SkinName A goome.SKIN_ constant or its name.
---@param skin goome.Skin? nil = no skin.
function Ui:push_skin(kind, skin) end

---A whole theme, one push.
---@param theme goome.Theme
function Ui:push_theme(theme) end

---@param icon integer A goome.ICON_ constant.
---@param bitmap goome.Bitmap?
function Ui:push_icon(icon, bitmap) end

---Pops the last n pushes of any kind.
---@param n integer? Default 1.
function Ui:pop(n) end

---Your own widget. Takes a spot like any widget, adds the hit rect and handles mouse and tab focus. w 0 is the normal widget width, h 0 is one line.
---@param id string
---@param w number? Default 0.
---@param h number? Default 0.
---@param flags integer? goome.ITEM_ flags. DRAG_X or DRAG_Y alone locks that axis.
---@return boolean happened True if something happened this frame.
---@return goome.Item item
function Ui:custom(id, w, h, flags) end

---Canvas to draw on inside the ui, clipped like the widgets. nil if there isn't one.
---@return goome.Canvas|nil
function Ui:canvas() end

---Keeps n numbers per id between frames, zero the first time. nil if it ran out of memory.
---@param id string
---@param n integer
---@return goome.Store|nil
function Ui:store(id, n) end

---The ui's theme, changes apply right away.
---@return goome.Theme
function Ui:theme() end

---Rebuilds the whole theme from an accent color.
---@param accent goome.Color
---@param dark boolean? Default true.
---@param radius number? Default 10.
function Ui:theme_make(accent, dark, radius) end

---@param preset goome.Preset
---@return true|nil
---@return string? err
---@return integer? code
function Ui:theme_preset(preset) end

---@param scale number
function Ui:scale(scale) end

---Mouse and keyboard behavior settings.
---@return goome.Config
function Ui:config() end

---Binds key combos to a text action.
---@param action integer A goome.ACT_ constant.
---@param combos string Like "ctrl+c".
---@return true|nil
---@return string? err
---@return integer? code
function Ui:bind(action, combos) end

---Animates a value toward the target.
---@param id string
---@param target number
---@param ms number? Default 200.
---@param ease integer? A goome.EASE_ constant. Default goome.EASE_OUT.
---@return number
function Ui:anim(id, target, ms, ease) end

---Same for a color.
---@param id string
---@param target goome.Color
---@param ms number?
---@param ease integer?
---@return goome.Color
function Ui:anim_color(id, target, ms, ease) end

---Turns the accessibility tree on or off.
---@param on boolean? Default true.
function Ui:a11y(on) end

---Says what the next `custom` is. Only applies to that one.
---@param role integer A goome.ROLE_ constant.
---@param label string?
function Ui:a11y_role(role, label) end

---Value for the next `custom`.
---@param value string?
function Ui:a11y_value(value) end

---@return goome.A11yNode[]
function Ui:a11y_tree() end

---A normal app window with a loop. Lua side, made by goome.app. Starts and stops itself in `run`.
---@class goome.App
---@field title string
---@field width integer
---@field height integer
---@field flags integer
---@field fps integer
---@field idle_ms integer
---@field light boolean?
---@field animate boolean Set it to true to keep redrawing every frame.
---@field running boolean
---@field frames integer Frames drawn so far.
---@field g goome.Goome? Only while running.
---@field ui goome.Ui? Only while running.
local App = {}

---Sets the function that draws each frame, gets `(ui, app)`. Frames only get drawn when something happened or animates.
---@param fn fun(ui: goome.Ui, app: goome.App)
---@return function fn
function App:frame(fn) end

---Handler for every event before the ui sees it. Return true to swallow it.
---@param fn fun(ev: goome.Event): boolean?
---@return function fn
function App:event(fn) end

---Called on the close button, return false to stay open.
---@param fn fun(app: goome.App): boolean?
---@return function fn
function App:on_close(fn) end

---Called once after the window opened.
---@param fn fun(app: goome.App)
---@return function fn
function App:on_start(fn) end

---Ask for a redraw.
function App:redraw() end

---Ends `run`.
function App:quit() end

---Opens the window. Only needed if you run the loop yourself with `step`.
---@return goome.App|nil self
---@return string? err
---@return integer? code
function App:start() end

---One loop turn: waits for events, draws if needed. Returns false once it should stop.
---@param wait boolean? false = don't wait.
---@return boolean running
function App:step(wait) end

---Closes the window.
function App:stop() end

---Opens it and loops until it closes. Errors in your frame function get rethrown after the cleanup.
---@param draw (fun(ui: goome.Ui, app: goome.App))? Same as `frame`.
---@return true|nil
---@return string? err
---@return integer? code
function App:run(draw) end

---@class goome
local goome = {}

---Version of goome this was built with.
---@type string
goome.VERSION = "0.5.5"

---Opens a goome. With a string it's the title. goome.AUTO picks the backend.
---@param opts string|goome.Opts?
---@return goome.Goome|nil
---@return string? err
---@return integer? code
function goome.open(opts) end

---A normal resizable window, centered.
---@param title string?
---@param w integer? Default 960.
---@param h integer? Default 640.
---@return goome.Goome|nil
---@return string? err
---@return integer? code
function goome.open_app(title, w, h) end

---No window, you get the frames with `last_frame` / `frame_copy`. Sizes are logical.
---@param w integer? Default 960.
---@param h integer? Default 640.
---@param scale number? Default 1.
---@return goome.Goome|nil
---@return string? err
---@return integer? code
function goome.open_offscreen(w, h, scale) end

---Makes an app. Use `app:run(function(ui) ... end)` or set the draw function with `app:frame`.
---@param title string|goome.AppOpts?
---@param width integer?
---@param height integer?
---@param opts goome.AppOpts?
---@return goome.App
function goome.app(title, width, height, opts) end

---Turns "alt+h" into a key and mods.
---@param combo string
---@return integer? key
---@return integer|string? mods_or_err
---@return integer? code
function goome.parse_combo(combo) end

---Sends a line to the control fifo of a running goome (see `g:control_path`). It shows up there as a goome.CONTROL event.
---@param state_dir string
---@param msg string
---@return true|nil
---@return string? err
---@return integer? code
function goome.send(state_dir, msg) end

---@return number ms
function goome.now_ms() end

---Frame pacing, use `pacer:wait()` as your poll timeout.
---@param fps integer? Default 60.
---@return goome.Pacer
function goome.pacer(fps) end

---A canvas you own, not tied to a window. Drawing works the same.
---@param w integer
---@param h integer
---@param stride integer? In pixels, default w.
---@param scale number? Default 1.
---@param ox number? Default 0.
---@param oy number? Default 0.
---@return goome.Canvas
function goome.canvas(w, h, stride, scale, ox, oy) end

---Radii table from one value, for the rrect functions.
---@param r number
---@return number[] radii tl, tr, br, bl
function goome.radius(r) end

---png, jpeg, bmp, ppm, qoi. Picks by content, not name.
---@param path string
---@return goome.Bitmap|nil
---@return string? err
---@return integer? code
function goome.bitmap_load(path) end

---Same as bitmap_load, from file contents.
---@param data string
---@return goome.Bitmap|nil
---@return string? err
---@return integer? code
function goome.bitmap_from_bytes(data) end

---Plain argb in, copied.
---@param pixels goome.HasPixels|integer[]|string Pixels, a list of argb numbers, or a string of BGRA bytes.
---@param w integer
---@param h integer
---@return goome.Bitmap|nil
---@return string? err
---@return integer? code
function goome.bitmap_from_argb(pixels, w, h) end

---A bitmap that points at the pixels instead of copying them. It keeps the source alive.
---@param pixels goome.HasPixels
---@param w integer? Default the source width.
---@param h integer? Default the source height.
---@param stride integer? Default the source stride.
---@return goome.Bitmap
function goome.bitmap_wrap(pixels, w, h, stride) end

---Why the last load failed.
---@return string
function goome.bitmap_error() end

---.ttf .otf .ttc
---@param path string
---@param index integer? Face in a .ttc, fontconfig hands these out.
---@return goome.Font|nil
---@return string? err
---@return integer? code
function goome.font_load(path, index) end

---@param data string
---@return goome.Font|nil
---@return string? err
---@return integer? code
function goome.font_from_bytes(data) end

---nil name = the desktops usual ui font. Gives nil if there isn't one.
---@param name string?
---@return goome.Font|nil
function goome.font_system(name) end

---Text size with the built in font.
---@param text string
---@param size number? Default 12.
---@return number width
---@return number height
function goome.measure(text, size) end

---@param size number? Default 12.
---@return number
function goome.line_height(size) end

---Picks the built in font by number, see `font_count`.
---@param font integer
function goome.set_font(font) end

---@return integer
function goome.font_count() end

---Short line for an error code.
---@param code integer
---@return string
function goome.strerror(code) end

---Writes a ppm file.
---@param path string
---@param pixels goome.HasPixels
---@return true|nil
---@return string? err
---@return integer? code
function goome.save_ppm(path, pixels) end

---A theme you own, starts dark. Use it with `ui:push_theme`.
---@return goome.Theme
function goome.theme() end

---@param ease integer A goome.EASE_ constant.
---@param t number 0 to 1.
---@return number
function goome.ease(ease, t) end

---Paragraph direction for all text, auto = from the first strong letter of each line.
---@param dir goome.Dir|integer? Default auto.
function goome.text_dir(dir) end

---Gives you a Pixels view of a canvas, image or bitmap.
---@param source goome.HasPixels
---@return goome.Pixels
function goome.pixels(source) end

---FNV hash of the pixels.
---@param source goome.HasPixels
---@param w integer?
---@param h integer?
---@return integer
function goome.hash(source, w, h) end

---Let goome pick the backend. The env var GOOME_BACKEND wins over what you pass.
---@type integer
goome.AUTO = 0

---Wayland backend.
---@type integer
goome.WAYLAND = 1

---GNOME backend.
---@type integer
goome.GNOME = 2

---Portal backend.
---@type integer
goome.PORTAL = 3

---X11 backend.
---@type integer
goome.X11 = 4

---Windows backend.
---@type integer
goome.WIN32 = 5

---macOS backend.
---@type integer
goome.MACOS = 6

---Test backend, driven by the test_frames, test_script and test_shots options.
---@type integer
goome.TEST = 7

---Offscreen backend, what open_offscreen uses.
---@type integer
goome.OFFSCREEN = 8

---See through overlay on top of everything.
---@type integer
goome.MODE_OVERLAY = 0

---A normal window.
---@type integer
goome.MODE_WINDOW = 1

---No window, you read the frames.
---@type integer
goome.MODE_OFFSCREEN = 2

---Window flag, add them up.
---@type integer
goome.WINDOW_RESIZABLE = 1

---Window flag, no border.
---@type integer
goome.WINDOW_BORDERLESS = 2

---Window flag, transparent background.
---@type integer
goome.WINDOW_TRANSPARENT = 4

---Window flag, stays on top.
---@type integer
goome.WINDOW_ON_TOP = 8

---Window flag, starts hidden.
---@type integer
goome.WINDOW_HIDDEN = 0x10

---Window flag, centered on open.
---@type integer
goome.WINDOW_CENTER = 0x20

---Window flag, no titlebar.
---@type integer
goome.WINDOW_NO_TITLEBAR = 0x40

---Window flag, no console window.
---@type integer
goome.WINDOW_NO_CONSOLE = 0x80

---No error.
---@type integer
goome.OK = 0

---This backend cant do that.
---@type integer
goome.ENOTSUP = -1

---Not allowed (permission or the user said no).
---@type integer
goome.EDENIED = -2

---No display to draw on.
---@type integer
goome.ENODISPLAY = -3

---That monitor is gone.
---@type integer
goome.EGONE = -4

---Nothing yet, try again in a bit.
---@type integer
goome.EAGAIN = -5

---Out of memory.
---@type integer
goome.ENOMEM = -6

---Bad argument.
---@type integer
goome.EARG = -7

---Can grab the screen.
---@type integer
goome.CAP_CAPTURE = 1

---Can read the pointer anywhere on the screen.
---@type integer
goome.CAP_GLOBAL_POINTER = 2

---Global hotkeys work.
---@type integer
goome.CAP_HOTKEYS = 4

---Can keep our overlay out of grabs.
---@type integer
goome.CAP_HIDE_SELF = 8

---Can take the keyboard.
---@type integer
goome.CAP_KEYBOARD = 0x10

---Window calls work.
---@type integer
goome.CAP_WINDOW = 0x20

---Clipboard works.
---@type integer
goome.CAP_CLIPBOARD = 0x40

---Can set the cursor.
---@type integer
goome.CAP_CURSOR = 0x80

---g:grab works.
---@type integer
goome.CAP_GRAB = 0x100

---The ui wants the mouse.
---@type integer
goome.WANT_MOUSE = 1

---The ui wants the keyboard.
---@type integer
goome.WANT_KEYBOARD = 2

---Event type: nothing.
---@type integer
goome.NONE = 0

---Event type: mouse button pressed.
---@type integer
goome.DOWN = 1

---Event type: mouse button released.
---@type integer
goome.UP = 2

---Event type: pointer moved.
---@type integer
goome.MOTION = 3

---Event type: scroll wheel, see dy.
---@type integer
goome.SCROLL = 4

---Event type: key pressed.
---@type integer
goome.KEY = 5

---Event type: a hotkey fired, id says which.
---@type integer
goome.HOTKEY = 6

---Event type: a line came in on the control fifo, msg = it.
---@type integer
goome.CONTROL = 7

---Event type: the monitors changed.
---@type integer
goome.MONITORS = 8

---Event type: asked to quit.
---@type integer
goome.QUIT = 9

---Event type: window close button, alt-f4 or cmd-w. The app decides.
---@type integer
goome.CLOSE = 10

---Event type: focus changed, id = 1 gained, 0 lost.
---@type integer
goome.FOCUS = 11

---Event type: a file got dropped on the window, x,y = where, path = the file.
---@type integer
goome.DROP = 12

---Event type: an ime, dead key or compose finished some text, msg = it.
---@type integer
goome.TEXT = 13

---Event type: the text being composed changed. Empty = composing ended.
---@type integer
goome.PREEDIT = 14

---Cursor shape for g:cursor.
---@type integer
goome.CURSOR_ARROW = 0

---Cursor shape for g:cursor.
---@type integer
goome.CURSOR_IBEAM = 1

---Cursor shape for g:cursor.
---@type integer
goome.CURSOR_HAND = 2

---Cursor shape for g:cursor.
---@type integer
goome.CURSOR_MOVE = 3

---Cursor shape for g:cursor.
---@type integer
goome.CURSOR_RESIZE_EW = 4

---Cursor shape for g:cursor.
---@type integer
goome.CURSOR_RESIZE_NS = 5

---Cursor shape for g:cursor.
---@type integer
goome.CURSOR_RESIZE_NWSE = 6

---Cursor shape for g:cursor.
---@type integer
goome.CURSOR_RESIZE_NESW = 7

---Cursor shape for g:cursor.
---@type integer
goome.CURSOR_WAIT = 8

---Cursor shape for g:cursor.
---@type integer
goome.CURSOR_NO = 9

---Cursor shape for g:cursor.
---@type integer
goome.CURSOR_HIDDEN = 10

---Edge bit for g:window_drag.
---@type integer
goome.EDGE_LEFT = 1

---Edge bit for g:window_drag.
---@type integer
goome.EDGE_RIGHT = 2

---Edge bit for g:window_drag.
---@type integer
goome.EDGE_TOP = 4

---Edge bit for g:window_drag.
---@type integer
goome.EDGE_BOTTOM = 8

---Window state for g:window_state.
---@type integer
goome.STATE_NORMAL = 0

---Window state for g:window_state.
---@type integer
goome.STATE_MINIMIZED = 1

---Window state for g:window_state.
---@type integer
goome.STATE_MAXIMIZED = 2

---Window state for g:window_state.
---@type integer
goome.STATE_FULLSCREEN = 3

---Key code.
---@type integer
goome.K_BACKSPACE = 8

---Key code.
---@type integer
goome.K_TAB = 9

---Key code.
---@type integer
goome.K_ENTER = 0xd

---Key code.
---@type integer
goome.K_ESC = 0x1b

---Key code.
---@type integer
goome.K_SPACE = 0x20

---Key code.
---@type integer
goome.K_DELETE = 0x7f

---Key code of F1, F2 and so on count up from here.
---@type integer
goome.K_F1 = 0x81

---Key code of F12.
---@type integer
goome.K_F12 = 0x8c

---Key code.
---@type integer
goome.K_LEFT = 0x90

---Key code.
---@type integer
goome.K_RIGHT = 0x91

---Key code.
---@type integer
goome.K_UP = 0x92

---Key code.
---@type integer
goome.K_DOWN = 0x93

---Key code.
---@type integer
goome.K_HOME = 0x94

---Key code.
---@type integer
goome.K_END = 0x95

---Key code.
---@type integer
goome.K_PGUP = 0x96

---Key code.
---@type integer
goome.K_PGDN = 0x97

---Key code.
---@type integer
goome.K_INSERT = 0x98

---Modifier bit.
---@type integer
goome.SHIFT = 0x100

---Modifier bit.
---@type integer
goome.CTRL = 0x200

---Modifier bit.
---@type integer
goome.ALT = 0x400

---Modifier bit.
---@type integer
goome.SUPER = 0x800

---Byte order in memory, premultiplied.
---@type integer
goome.FMT_BGRA_PREMUL = 0

---Byte order in memory, premultiplied.
---@type integer
goome.FMT_RGBA_PREMUL = 1

---Byte order in memory, unpremultiplied.
---@type integer
goome.FMT_BGRA = 2

---Byte order in memory, unpremultiplied.
---@type integer
goome.FMT_RGBA = 3

---Text direction from the first strong letter of each line.
---@type integer
goome.DIR_AUTO = 0

---Left to right.
---@type integer
goome.DIR_LTR = 1

---Right to left.
---@type integer
goome.DIR_RTL = 2

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_ARROW_DOWN = 0

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_ARROW_RIGHT = 1

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_ARROW_UP = 2

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_ARROW_LEFT = 3

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_CHECK = 4

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_RADIO_DOT = 5

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_CLOSE = 6

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_MINIMIZE = 7

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_MAXIMIZE = 8

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_RESTORE = 9

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_RESIZE = 10

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_SORT_UP = 11

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_SORT_DOWN = 12

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_PLUS = 13

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_MINUS = 14

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_SLIDER_KNOB = 15

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_TOGGLE_KNOB = 16

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_COLLAPSE = 17

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_EXPAND = 18

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_DRAG_HANDLE = 19

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_TOAST = 20

---Icon slot for theme:icon and ui:push_icon.
---@type integer
goome.ICON_PICKER = 21

---How many icons there are.
---@type integer
goome.ICON_COUNT = 22

---ui:window flag, can be moved.
---@type integer
goome.WIN_MOVE = 1

---ui:window flag, can be resized.
---@type integer
goome.WIN_RESIZE = 2

---ui:window flag, can be collapsed.
---@type integer
goome.WIN_COLLAPSE = 4

---ui:window flag, no title bar.
---@type integer
goome.WIN_NO_TITLE = 8

---ui:window flag, has a close button.
---@type integer
goome.WIN_CLOSE = 0x10

---ui:input_ex flag, shows dots.
---@type integer
goome.INPUT_PASSWORD = 1

---ui:input_ex flag, read only.
---@type integer
goome.INPUT_READONLY = 2

---ui:input_ex flag, numbers only.
---@type integer
goome.INPUT_NUMBER = 4

---ui:input_ex flag, dont select all on focus.
---@type integer
goome.INPUT_NO_SELECT_ON_FOCUS = 8

---ui:input_ex flag, enter counts as a change.
---@type integer
goome.INPUT_ENTER_RETURNS = 0x10

---ui:app flag, draws a titlebar.
---@type integer
goome.APP_TITLEBAR = 1

---ui:app flag, room for a menubar.
---@type integer
goome.APP_MENUBAR = 2

---ui:app flag, room for a statusbar.
---@type integer
goome.APP_STATUSBAR = 4

---ui:app flag, no padding.
---@type integer
goome.APP_NO_PAD = 8

---ui:text_edit flag, read only.
---@type integer
goome.EDIT_READONLY = 1

---ui:text_edit flag, line numbers.
---@type integer
goome.EDIT_LINE_NUMBERS = 2

---ui:text_edit flag, wraps lines.
---@type integer
goome.EDIT_WRAP = 4

---ui:text_edit flag, monospace font.
---@type integer
goome.EDIT_MONO = 8

---ui:table flag, clickable headers.
---@type integer
goome.TABLE_SORTABLE = 1

---ui:table flag, resizable columns.
---@type integer
goome.TABLE_RESIZABLE = 2

---ui:table flag, striped rows.
---@type integer
goome.TABLE_STRIPES = 4

---ui:table flag, borders.
---@type integer
goome.TABLE_BORDERS = 8

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_BG = 0

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_PANEL = 1

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_BORDER = 2

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TEXT = 3

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TEXT_DIM = 4

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_ACCENT = 5

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_ACCENT_TEXT = 6

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_HOVER = 7

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_ACTIVE = 8

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_INPUT_BG = 9

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SHADOW = 10

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_RADIUS = 11

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_PAD = 12

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_GAP = 13

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_BORDER_WIDTH = 14

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_FONT_SIZE = 15

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SHADOW_BLUR = 16

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_ANIM_MS = 17

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_FOCUS = 18

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SELECT = 19

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_CARET = 20

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_LINK = 21

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_BADGE = 22

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TOAST = 23

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TOOLTIP = 24

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_DANGER = 25

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_KNOB = 26

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_DIM = 27

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_CHECK_SIZE = 28

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_CHECK_RADIUS = 29

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TOGGLE_W = 30

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TOGGLE_H = 31

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SLIDER_H = 32

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SLIDER_TRACK = 33

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_KNOB_SIZE = 34

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SCROLL_W = 35

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SCROLL_MIN = 36

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_ITEM_H = 37

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_MENU_ITEM_H = 38

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TAB_H = 39

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_WIN_TITLE_H = 40

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_APP_TITLE_H = 41

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_MENUBAR_H = 42

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_STATUSBAR_H = 43

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_FOCUS_W = 44

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_FOCUS_GAP = 45

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SEP_W = 46

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_GRIP = 47

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_INDENT = 48

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_PLOT_W = 49

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SPINNER = 50

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_CARET_W = 51

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_WIN_MIN_W = 52

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_WIN_MIN_H = 53

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_POP_GAP = 54

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_MENU_GAP = 55

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TIP_PAD_X = 56

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TIP_PAD_Y = 57

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TIP_X = 58

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TIP_Y = 59

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TIP_RADIUS = 60

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SHADOW_X = 61

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SHADOW_Y = 62

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_ALIGN = 63

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_HEADING_SIZE = 64

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_SMALL_SIZE = 65

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_EASE = 66

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_HOVER_MS = 67

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_PRESS_MS = 68

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_POPUP_MS = 69

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_COLLAPSE_MS = 70

---Style setting for ui:push_color and ui:push_num, same name as the theme field.
---@type integer
goome.S_TOAST_FADE_MS = 71

---How many style settings there are.
---@type integer
goome.S_COUNT = 72

---Value for the theme align setting.
---@type integer
goome.ALIGN_AUTO = 0

---Value for the theme align setting.
---@type integer
goome.ALIGN_LEFT = 1

---Value for the theme align setting.
---@type integer
goome.ALIGN_CENTER = 2

---Value for the theme align setting.
---@type integer
goome.ALIGN_RIGHT = 3

---Easing for ui:anim and goome.ease.
---@type integer
goome.EASE_SMOOTH = 0

---Easing for ui:anim and goome.ease.
---@type integer
goome.EASE_LINEAR = 1

---Easing for ui:anim and goome.ease.
---@type integer
goome.EASE_OUT = 2

---Easing for ui:anim and goome.ease.
---@type integer
goome.EASE_IN_OUT = 3

---Easing for ui:anim and goome.ease.
---@type integer
goome.EASE_BACK = 4

---Easing for ui:anim and goome.ease.
---@type integer
goome.EASE_CUSTOM = 5

---Easing for ui:anim and goome.ease.
---@type integer
goome.EASE_IN = 6

---Easing for ui:anim and goome.ease.
---@type integer
goome.EASE_SPRING = 7

---Easing for ui:anim and goome.ease.
---@type integer
goome.EASE_BOUNCE = 8

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_BUTTON = 0

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_PANEL = 1

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_INPUT = 2

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_CHECKBOX = 3

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_RADIO = 4

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_TOGGLE = 5

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_SLIDER_TRACK = 6

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_SLIDER_FILL = 7

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_SCROLLBAR = 8

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_TAB = 9

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_TITLEBAR = 10

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_TOOLTIP = 11

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_MENU = 12

---Skin kind for ui:push_skin.
---@type integer
goome.SKIN_POPUP = 13

---How many skin kinds there are.
---@type integer
goome.SKIN_COUNT = 14

---ui:custom flag, drag on the x axis only.
---@type integer
goome.ITEM_DRAG_X = 1

---ui:custom flag, drag on the y axis only.
---@type integer
goome.ITEM_DRAG_Y = 2

---ui:custom flag, tab can focus it.
---@type integer
goome.ITEM_FOCUSABLE = 4

---ui:custom flag, no hit rect.
---@type integer
goome.ITEM_NO_HIT = 8

---ui:custom flag, repeat while held.
---@type integer
goome.ITEM_REPEAT = 0x10

---Theme preset.
---@type integer
goome.PRESET_DARK = 0

---Theme preset.
---@type integer
goome.PRESET_LIGHT = 1

---Theme preset.
---@type integer
goome.PRESET_MIDNIGHT = 2

---Theme preset.
---@type integer
goome.PRESET_PAPER = 3

---Theme preset.
---@type integer
goome.PRESET_MINT = 4

---Theme preset.
---@type integer
goome.PRESET_HIGH_CONTRAST = 5

---Theme preset.
---@type integer
goome.PRESET_ROSE = 6

---How many presets there are.
---@type integer
goome.PRESET_COUNT = 7

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_COPY = 0

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_CUT = 1

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_PASTE = 2

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_UNDO = 3

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_REDO = 4

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_SELECT_ALL = 5

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_WORD_LEFT = 6

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_WORD_RIGHT = 7

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_DEL_WORD_LEFT = 8

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_DEL_WORD_RIGHT = 9

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_DOC_START = 10

---Text action for ui:bind and config:keys.
---@type integer
goome.ACT_DOC_END = 11

---How many text actions there are.
---@type integer
goome.ACT_COUNT = 12

---Cursor slot for config:cursor.
---@type integer
goome.CUR_BUTTON = 0

---Cursor slot for config:cursor.
---@type integer
goome.CUR_INPUT = 1

---Cursor slot for config:cursor.
---@type integer
goome.CUR_LINK = 2

---Cursor slot for config:cursor.
---@type integer
goome.CUR_DRAG_VALUE = 3

---Cursor slot for config:cursor.
---@type integer
goome.CUR_SPLIT_X = 4

---Cursor slot for config:cursor.
---@type integer
goome.CUR_SPLIT_Y = 5

---Cursor slot for config:cursor.
---@type integer
goome.CUR_GRIP = 6

---Cursor slot for config:cursor.
---@type integer
goome.CUR_COLUMN = 7

---Cursor slot for config:cursor.
---@type integer
goome.CUR_DRAG_DROP = 8

---Cursor slot for config:cursor.
---@type integer
goome.CUR_CUSTOM_X = 9

---Cursor slot for config:cursor.
---@type integer
goome.CUR_CUSTOM_Y = 10

---Cursor slot for config:cursor.
---@type integer
goome.CUR_CUSTOM_XY = 11

---How many cursor slots there are.
---@type integer
goome.CUR_COUNT = 12

---Accessibility role.
---@type integer
goome.ROLE_NONE = 0

---Accessibility role.
---@type integer
goome.ROLE_WINDOW = 1

---Accessibility role.
---@type integer
goome.ROLE_BUTTON = 2

---Accessibility role.
---@type integer
goome.ROLE_CHECKBOX = 3

---Accessibility role.
---@type integer
goome.ROLE_RADIO = 4

---Accessibility role.
---@type integer
goome.ROLE_SLIDER = 5

---Accessibility role.
---@type integer
goome.ROLE_TEXT = 6

---Accessibility role.
---@type integer
goome.ROLE_INPUT = 7

---Accessibility role.
---@type integer
goome.ROLE_COMBO = 8

---Accessibility role.
---@type integer
goome.ROLE_LIST = 9

---Accessibility role.
---@type integer
goome.ROLE_ITEM = 10

---Accessibility role.
---@type integer
goome.ROLE_TAB = 11

---Accessibility role.
---@type integer
goome.ROLE_MENU = 12

---Accessibility role.
---@type integer
goome.ROLE_MENUITEM = 13

---Accessibility role.
---@type integer
goome.ROLE_TABLE = 14

---Accessibility role.
---@type integer
goome.ROLE_TREE = 15

---Accessibility role.
---@type integer
goome.ROLE_PROGRESS = 16

---Accessibility role.
---@type integer
goome.ROLE_IMAGE = 17

---Accessibility role.
---@type integer
goome.ROLE_GROUP = 18

---Accessibility role.
---@type integer
goome.ROLE_DIALOG = 19

---Accessibility state bit.
---@type integer
goome.A11Y_FOCUSED = 1

---Accessibility state bit.
---@type integer
goome.A11Y_CHECKED = 2

---Accessibility state bit.
---@type integer
goome.A11Y_DISABLED = 4

---Accessibility state bit.
---@type integer
goome.A11Y_EXPANDED = 8

---Accessibility state bit.
---@type integer
goome.A11Y_SELECTED = 0x10

return goome
