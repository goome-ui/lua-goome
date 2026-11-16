#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h>

#include "goome.h"
#include "lua.h"
#include "lauxlib.h"

#if defined(_WIN32)
#define LG_EXPORT __declspec(dllexport)
#else
#define LG_EXPORT __attribute__((visibility("default")))
#endif

#if LUA_VERSION_NUM < 502
#define LG_LEN(L, i) ((int)lua_objlen(L, i))
#else
#define LG_LEN(L, i) ((int)lua_rawlen(L, i))
#endif

#if LUA_VERSION_NUM < 502
#define LG_GETUV(L, i) lua_getfenv(L, i)
#define LG_SETUV(L, i) lua_setfenv(L, i)
#elif LUA_VERSION_NUM < 504
#define LG_GETUV(L, i) lua_getuservalue(L, i)
#define LG_SETUV(L, i) lua_setuservalue(L, i)
#else
#define LG_GETUV(L, i) lua_getiuservalue(L, i, 1)
#define LG_SETUV(L, i) lua_setiuservalue(L, i, 1)
#endif

#define MT_G "goome.Goome"
#define MT_CANVAS "goome.Canvas"
#define MT_IMAGE "goome.Image"
#define MT_PIX "goome.Pixels"
#define MT_BMP "goome.Bitmap"
#define MT_FONT "goome.Font"
#define MT_UI "goome.Ui"
#define MT_THEME "goome.Theme"
#define MT_CFG "goome.Config"
#define MT_PACER "goome.Pacer"
#define MT_STORE "goome.Store"

typedef struct lg_ui lg_ui;

typedef struct {
    goome *g;
    unsigned grab_gen[64];
    unsigned begin_gen;
    int live, keep;
    lg_ui *uis;
} lg_g;

typedef struct {
    double x, y, w, h;
    int open;
} lg_win;

struct lg_ui {
    lg_win *wst[32];
    int wref[32], nw;
    goome_ui *u;
    lg_g *g;
    int gref, refs, live, ease_ref;
    lua_State *L;
    char *mask;
    lg_ui *next;
};

typedef struct {
    goome_canvas *c;
    goome_canvas own;
    uint32_t *buf;
    goome_rect *hits;
    int nhits, caphits;
} lg_canvas;

typedef struct {
    goome_image img;
    lg_g *g;
    int gref, kind;
    unsigned gen;
} lg_image;

typedef struct {
    goome_bitmap b;
    int closed, users, keep;
} lg_bmp;

typedef struct lg_font lg_font;
struct lg_font {
    goome_font *f;
    int closed, users, nfb;
    lg_font *fb[8];
};

typedef struct {
    int ref;
} lg_pix;

typedef struct {
    goome_theme *t;
    goome_theme own;
    int uiref, refs;
} lg_theme;

typedef struct {
    int uiref;
} lg_cfg;

typedef struct {
    double *p;
    int n, uiref;
} lg_store;

typedef struct {
    uint32_t *px;
    int w, h, stride, writable;
} lg_px;

static uint32_t lg_u32(lua_State *L, int i)
{
    lua_Number n = luaL_checknumber(L, i);
    if (n < 0) return (uint32_t)(int32_t)(long long)n;
    return (uint32_t)(unsigned long long)n;
}

static uint32_t lg_optu32(lua_State *L, int i, uint32_t d)
{
    return lua_isnoneornil(L, i) ? d : lg_u32(L, i);
}

static int lg_bool(lua_State *L, int i)
{
    if (lua_isboolean(L, i)) return lua_toboolean(L, i);
    if (lua_isnumber(L, i)) return lua_tonumber(L, i) != 0;
    return lua_toboolean(L, i);
}

static void lg_setfuncs(lua_State *L, const luaL_Reg *r)
{
    for (; r->name; r++) {
        lua_pushcfunction(L, r->func);
        lua_setfield(L, -2, r->name);
    }
}

static void *lg_test(lua_State *L, int i, const char *mt)
{
    void *p = lua_touserdata(L, i);
    if (!p || !lua_getmetatable(L, i)) return NULL;
    luaL_getmetatable(L, mt);
    int same = lua_rawequal(L, -1, -2);
    lua_pop(L, 2);
    return same ? p : NULL;
}

static void *lg_check(lua_State *L, int i, const char *mt)
{
    void *p = lg_test(L, i, mt);
    if (!p) luaL_error(L, "bad argument #%d, wanted a %s", i, mt);
    return p;
}

static const char *lg_tostr(lua_State *L, int i)
{
    if (lua_type(L, i) == LUA_TBOOLEAN) return lua_toboolean(L, i) ? "true" : "false";
    return luaL_checkstring(L, i);
}

static void lg_newmt(lua_State *L, const char *mt)
{
    luaL_getmetatable(L, mt);
    lua_setmetatable(L, -2);
}

static int lg_fail(lua_State *L, goome *g, int rc)
{
    const char *e = g ? goome_error(g) : NULL;
    lua_pushnil(L);
    lua_pushstring(L, e && *e ? e : goome_strerror(rc));
    lua_pushinteger(L, rc);
    return 3;
}

static int lg_res(lua_State *L, goome *g, int rc)
{
    if (rc < 0) return lg_fail(L, g, rc);
    lua_pushboolean(L, 1);
    return 1;
}

static double lg_fnum(lua_State *L, int t, const char *k, double d)
{
    lua_getfield(L, t, k);
    double v = lua_isnumber(L, -1) ? lua_tonumber(L, -1) : d;
    lua_pop(L, 1);
    return v;
}

static int lg_fbool(lua_State *L, int t, const char *k, int d)
{
    lua_getfield(L, t, k);
    int v = lua_isnil(L, -1) ? d : lg_bool(L, -1);
    lua_pop(L, 1);
    return v;
}

static int lg_ref(lua_State *L, int i)
{
    lua_pushvalue(L, i);
    return luaL_ref(L, LUA_REGISTRYINDEX);
}

static void lg_getref(lua_State *L, int r)
{
    lua_rawgeti(L, LUA_REGISTRYINDEX, r);
}

static void lg_unref(lua_State *L, int *r)
{
    if (*r != LUA_NOREF && *r != LUA_REFNIL) luaL_unref(L, LUA_REGISTRYINDEX, *r);
    *r = LUA_NOREF;
}

static void lg_push_rect(lua_State *L, const goome_rect *r)
{
    lua_createtable(L, 0, 4);
    lua_pushinteger(L, r->x);
    lua_setfield(L, -2, "x");
    lua_pushinteger(L, r->y);
    lua_setfield(L, -2, "y");
    lua_pushinteger(L, r->w);
    lua_setfield(L, -2, "w");
    lua_pushinteger(L, r->h);
    lua_setfield(L, -2, "h");
}

static int lg_rect_at(lua_State *L, int i, goome_rect *r)
{
    if (lua_istable(L, i)) {
        lua_rawgeti(L, i, 1);
        int pos = !lua_isnil(L, -1);
        lua_pop(L, 1);
        if (pos) {
            int v[4];
            for (int k = 0; k < 4; k++) {
                lua_rawgeti(L, i, k + 1);
                v[k] = (int)lua_tonumber(L, -1);
                lua_pop(L, 1);
            }
            r->x = v[0], r->y = v[1], r->w = v[2], r->h = v[3];
        } else {
            r->x = (int)lg_fnum(L, i, "x", 0);
            r->y = (int)lg_fnum(L, i, "y", 0);
            r->w = (int)lg_fnum(L, i, "w", 0);
            r->h = (int)lg_fnum(L, i, "h", 0);
        }
        return 1;
    }
    if (lua_isnumber(L, i)) {
        r->x = (int)luaL_checknumber(L, i);
        r->y = (int)luaL_checknumber(L, i + 1);
        r->w = (int)luaL_checknumber(L, i + 2);
        r->h = (int)luaL_checknumber(L, i + 3);
        return 1;
    }
    return 0;
}

static void lg_track(lua_State *L, int live, int i)
{
    if (i < 0) i = lua_gettop(L) + i + 1;
    lg_getref(L, live);
    lua_pushvalue(L, i);
    lua_rawseti(L, -2, LG_LEN(L, -2) + 1);
    lua_pop(L, 1);
}

static void lg_drop_live(lua_State *L, int live)
{
    lg_getref(L, live);
    int n = LG_LEN(L, -1);
    for (int k = 1; k <= n; k++) {
        lua_rawgeti(L, -1, k);
        lg_canvas *c = (lg_canvas *)lg_test(L, -1, MT_CANVAS);
        if (c) c->c = NULL;
        lua_pop(L, 1);
        lua_pushnil(L);
        lua_rawseti(L, -2, k);
    }
    lua_pop(L, 1);
}

static lg_g *lg_gopen(lua_State *L, int i)
{
    lg_g *g = (lg_g *)lg_check(L, i, MT_G);
    if (!g->g) luaL_error(L, "this goome is closed");
    return g;
}

static void lg_ui_free(lua_State *L, lg_ui *u);
static void lg_win_pop(lua_State *L, lg_ui *u, int write);

static int lg_push_g(lua_State *L, goome *gg, int keep)
{
    lg_g *g = (lg_g *)lua_newuserdata(L, sizeof(lg_g));
    memset(g, 0, sizeof(*g));
    g->g = gg;
    g->keep = LUA_NOREF;
    if (keep) g->keep = lg_ref(L, keep);
    lua_newtable(L);
    g->live = luaL_ref(L, LUA_REGISTRYINDEX);
    lg_newmt(L, MT_G);
    return 1;
}

static const char *const lg_backends[] = {"auto", "wayland", "gnome", "portal", "x11", "win32", "macos", "test", "offscreen", NULL};
static const char *const lg_modes[] = {"overlay", "window", "offscreen", NULL};

static int lg_named(lua_State *L, int i, const char *const *names, int d)
{
    if (lua_isnoneornil(L, i)) return d;
    if (lua_isnumber(L, i)) return (int)lua_tonumber(L, i);
    const char *s = luaL_checkstring(L, i);
    for (int k = 0; names[k]; k++)
        if (!strcmp(names[k], s)) return k;
    return luaL_error(L, "dont know \"%s\"", s);
}

static const char *lg_fstr(lua_State *L, int t, const char *k)
{
    lua_getfield(L, t, k);
    const char *s = lua_isstring(L, -1) ? lua_tostring(L, -1) : NULL;
    lua_pop(L, 1);
    return s;
}

static int l_open(lua_State *L)
{
    goome_opts o;
    memset(&o, 0, sizeof(o));
    if (lua_isstring(L, 1)) {
        o.title = lua_tostring(L, 1);
    } else if (lua_istable(L, 1)) {
        o.title = lg_fstr(L, 1, "title");
        lua_getfield(L, 1, "backend");
        o.backend = lg_named(L, -1, lg_backends, 0);
        lua_pop(L, 1);
        lua_getfield(L, 1, "mode");
        o.mode = lg_named(L, -1, lg_modes, 0);
        lua_pop(L, 1);
        o.state_dir = lg_fstr(L, 1, "state_dir");
        o.no_capture = lg_fbool(L, 1, "no_capture", 0);
        o.capture_fps = (int)lg_fnum(L, 1, "capture_fps", 0);
        o.hide_self = lg_fbool(L, 1, "hide_self", 0);
        o.test_frames = lg_fstr(L, 1, "test_frames");
        o.test_script = lg_fstr(L, 1, "test_script");
        o.test_shots = lg_fstr(L, 1, "test_shots");
        o.width = (int)lg_fnum(L, 1, "width", 0);
        o.height = (int)lg_fnum(L, 1, "height", 0);
        o.min_width = (int)lg_fnum(L, 1, "min_width", 0);
        o.min_height = (int)lg_fnum(L, 1, "min_height", 0);
        o.window_flags = (int)lg_fnum(L, 1, "window_flags", 0);
        o.scale = lg_fnum(L, 1, "scale", 0);
    }
    int err = 0;
    goome *g = goome_open(&o, &err);
    if (!g) return lg_fail(L, NULL, err ? err : GOOME_ENODISPLAY);
    return lg_push_g(L, g, lua_istable(L, 1) || lua_isstring(L, 1) ? 1 : 0);
}

static int l_open_app(lua_State *L)
{
    int err = 0;
    goome *g = goome_open_app(luaL_optstring(L, 1, NULL), (int)luaL_optnumber(L, 2, 0), (int)luaL_optnumber(L, 3, 0), &err);
    if (!g) return lg_fail(L, NULL, err ? err : GOOME_ENODISPLAY);
    return lg_push_g(L, g, lua_isstring(L, 1) ? 1 : 0);
}

static int l_open_offscreen(lua_State *L)
{
    goome_opts o;
    memset(&o, 0, sizeof(o));
    o.mode = GOOME_MODE_OFFSCREEN;
    o.width = (int)luaL_optnumber(L, 1, 0);
    o.height = (int)luaL_optnumber(L, 2, 0);
    o.scale = luaL_optnumber(L, 3, 0);
    int err = 0;
    goome *g = goome_open(&o, &err);
    if (!g) return lg_fail(L, NULL, err ? err : GOOME_ENODISPLAY);
    return lg_push_g(L, g, 0);
}

static int g_close(lua_State *L)
{
    lg_g *g = (lg_g *)lg_check(L, 1, MT_G);
    if (!g->g) return 0;
    while (g->uis) lg_ui_free(L, g->uis);
    lg_drop_live(L, g->live);
    goome_close(g->g);
    g->g = NULL;
    return 0;
}

static int g_gc(lua_State *L)
{
    g_close(L);
    lg_g *g = (lg_g *)lua_touserdata(L, 1);
    lg_unref(L, &g->live);
    lg_unref(L, &g->keep);
    return 0;
}

static int g_closed(lua_State *L)
{
    lua_pushboolean(L, ((lg_g *)lg_check(L, 1, MT_G))->g == NULL);
    return 1;
}

static int g_error(lua_State *L)
{
    lua_pushstring(L, goome_error(lg_gopen(L, 1)->g));
    return 1;
}

static int g_backend_name(lua_State *L)
{
    lua_pushstring(L, goome_backend_name(lg_gopen(L, 1)->g));
    return 1;
}

static int g_caps(lua_State *L)
{
    lua_pushinteger(L, goome_caps(lg_gopen(L, 1)->g));
    return 1;
}

static int g_can(lua_State *L)
{
    int c = goome_caps(lg_gopen(L, 1)->g);
    lua_pushboolean(L, (c & (int)luaL_checknumber(L, 2)) != 0);
    return 1;
}

static int g_monitors(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    goome_monitor m[32];
    int n = goome_monitors(g->g, m, 32);
    if (n < 0) return lg_fail(L, g->g, n);
    if (n > 32) n = 32;
    lua_createtable(L, n, 0);
    for (int k = 0; k < n; k++) {
        lua_createtable(L, 0, 7);
        lua_pushinteger(L, m[k].id);
        lua_setfield(L, -2, "id");
        lua_pushstring(L, m[k].name);
        lua_setfield(L, -2, "name");
        lg_push_rect(L, &m[k].area);
        lua_setfield(L, -2, "area");
        lua_pushnumber(L, m[k].scale);
        lua_setfield(L, -2, "scale");
        lua_pushinteger(L, m[k].pw);
        lua_setfield(L, -2, "pw");
        lua_pushinteger(L, m[k].ph);
        lua_setfield(L, -2, "ph");
        lua_pushinteger(L, m[k].rotation);
        lua_setfield(L, -2, "rotation");
        lua_rawseti(L, -2, k + 1);
    }
    return 1;
}

static int lg_push_image(lua_State *L, int gi, lg_g *g, const goome_image *img, int kind)
{
    lg_image *im = (lg_image *)lua_newuserdata(L, sizeof(lg_image));
    memset(im, 0, sizeof(*im));
    im->img = *img;
    im->g = g;
    im->kind = kind;
    im->gen = kind ? g->begin_gen : g->grab_gen[img->mon & 63];
    im->gref = lg_ref(L, gi);
    lg_newmt(L, MT_IMAGE);
    return 1;
}

static int g_capture(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    int mon = (int)luaL_optnumber(L, 2, 0);
    goome_rect r;
    int has = lg_rect_at(L, 3, &r);
    goome_image img;
    int rc = goome_capture(g->g, mon, has ? &r : NULL, &img);
    if (rc < 0) return lg_fail(L, g->g, rc);
    g->grab_gen[mon & 63]++;
    return lg_push_image(L, 1, g, &img, 0);
}

static int g_capture_wait(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    int mon = (int)luaL_optnumber(L, 2, 0);
    goome_rect r;
    int has = lg_rect_at(L, 3, &r);
    int ms = (int)luaL_optnumber(L, has && lua_isnumber(L, 3) ? 7 : 4, 5000);
    long until = goome_now_ms() + ms;
    goome_image img;
    for (;;) {
        int rc = goome_capture(g->g, mon, has ? &r : NULL, &img);
        if (rc >= 0) break;
        if (rc != GOOME_EAGAIN || goome_now_ms() > until) return lg_fail(L, g->g, rc);
        goome_event ev;
        goome_poll(g->g, &ev, 20);
    }
    g->grab_gen[mon & 63]++;
    return lg_push_image(L, 1, g, &img, 0);
}

static int g_alpha_at(lua_State *L)
{
    lua_pushinteger(L, goome_alpha_at(lg_gopen(L, 1)->g, luaL_checknumber(L, 2), luaL_checknumber(L, 3)));
    return 1;
}

static int lg_push_canvas(lua_State *L, goome_canvas *c, int live)
{
    lg_canvas *cv = (lg_canvas *)lua_newuserdata(L, sizeof(lg_canvas));
    memset(cv, 0, sizeof(*cv));
    cv->c = c;
    lg_newmt(L, MT_CANVAS);
    if (live != LUA_NOREF) lg_track(L, live, -1);
    return 1;
}

static int g_begin(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    g->begin_gen++;
    goome_canvas *c = goome_begin(g->g, (int)luaL_optnumber(L, 2, 0));
    if (!c) {
        lua_pushnil(L);
        return 1;
    }
    return lg_push_canvas(L, c, g->live);
}

static lg_canvas *lg_cv(lua_State *L, int i)
{
    lg_canvas *c = (lg_canvas *)lg_check(L, i, MT_CANVAS);
    if (!c->c) luaL_error(L, "this canvas got handed back already, get a new one from begin()");
    return c;
}

static void lg_add_hit(lg_canvas *c, double x, double y, double w, double h)
{
    if (c->nhits == c->caphits) {
        int n = c->caphits ? c->caphits * 2 : 8;
        goome_rect *p = (goome_rect *)realloc(c->hits, sizeof(goome_rect) * n);
        if (!p) return;
        c->hits = p, c->caphits = n;
    }
    goome_rect *r = &c->hits[c->nhits++];
    r->x = (int)x, r->y = (int)y, r->w = (int)(w + 0.999), r->h = (int)(h + 0.999);
}

static int g_end(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    lg_canvas *c = lg_cv(L, 2);
    if (lua_istable(L, 3)) {
        int n = LG_LEN(L, 3);
        for (int k = 1; k <= n; k++) {
            lua_rawgeti(L, 3, k);
            goome_rect r;
            if (lg_rect_at(L, lua_gettop(L), &r)) lg_add_hit(c, r.x, r.y, r.w, r.h);
            lua_pop(L, 1);
        }
    }
    int rc = goome_end(g->g, c->c, c->hits, c->nhits);
    c->nhits = 0;
    c->c = NULL;
    return lg_res(L, g->g, rc);
}

static void lg_ev_to(lua_State *L, int t, goome_event *ev)
{
    memset(ev, 0, sizeof(*ev));
    ev->type = (int)lg_fnum(L, t, "type", 0);
    ev->x = lg_fnum(L, t, "x", 0);
    ev->y = lg_fnum(L, t, "y", 0);
    ev->mon = (int)lg_fnum(L, t, "mon", 0);
    ev->button = (int)lg_fnum(L, t, "button", 0);
    ev->dy = (int)lg_fnum(L, t, "dy", 0);
    ev->key = (int)lg_fnum(L, t, "key", 0);
    ev->mods = (int)lg_fnum(L, t, "mods", 0);
    ev->id = (int)lg_fnum(L, t, "id", 0);
    const char *s = lg_fstr(L, t, "text");
    if (s) strncpy(ev->text, s, sizeof(ev->text) - 1);
    s = lg_fstr(L, t, "msg");
    if (s) strncpy(ev->msg, s, sizeof(ev->msg) - 1);
}

static void lg_ev_push(lua_State *L, const goome_event *ev, goome *g)
{
    lua_createtable(L, 0, 12);
    lua_pushinteger(L, ev->type);
    lua_setfield(L, -2, "type");
    lua_pushnumber(L, ev->x);
    lua_setfield(L, -2, "x");
    lua_pushnumber(L, ev->y);
    lua_setfield(L, -2, "y");
    lua_pushinteger(L, ev->mon);
    lua_setfield(L, -2, "mon");
    lua_pushinteger(L, ev->button);
    lua_setfield(L, -2, "button");
    lua_pushinteger(L, ev->dy);
    lua_setfield(L, -2, "dy");
    lua_pushinteger(L, ev->key);
    lua_setfield(L, -2, "key");
    lua_pushinteger(L, ev->mods);
    lua_setfield(L, -2, "mods");
    char t[9];
    memcpy(t, ev->text, 8);
    t[8] = 0;
    lua_pushstring(L, t);
    lua_setfield(L, -2, "text");
    lua_pushinteger(L, ev->id);
    lua_setfield(L, -2, "id");
    char m[65];
    memcpy(m, ev->msg, 64);
    m[64] = 0;
    lua_pushstring(L, m);
    lua_setfield(L, -2, "msg");
    if (ev->type == GOOME_DROP && g) {
        const char *p = goome_drop_path(g);
        lua_pushstring(L, p ? p : m);
        lua_setfield(L, -2, "path");
    }
    if ((ev->type == GOOME_TEXT || ev->type == GOOME_PREEDIT) && g) {
        const char *p = goome_event_text(g);
        lua_pushstring(L, p && (*p || ev->type == GOOME_PREEDIT) ? p : m);
        lua_setfield(L, -2, "ime");
        if (ev->type == GOOME_PREEDIT) {
            lua_pushinteger(L, goome_preedit_cursor(g));
            lua_setfield(L, -2, "caret");
        }
    }
}

static int g_poll(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    goome_event ev;
    int rc = goome_poll(g->g, &ev, (int)luaL_optnumber(L, 2, 0));
    if (rc < 0) return lg_fail(L, g->g, rc);
    if (rc == 0) {
        lua_pushnil(L);
        return 1;
    }
    lg_ev_push(L, &ev, g->g);
    return 1;
}

static int g_events_next(lua_State *L)
{
    lg_g *g = (lg_g *)lua_touserdata(L, lua_upvalueindex(1));
    if (!g->g) return 0;
    int ms = (int)lua_tonumber(L, lua_upvalueindex(2));
    lua_pushinteger(L, 0);
    lua_replace(L, lua_upvalueindex(2));
    goome_event ev;
    if (goome_poll(g->g, &ev, ms) <= 0) return 0;
    lg_ev_push(L, &ev, g->g);
    return 1;
}

static int g_events(lua_State *L)
{
    lg_gopen(L, 1);
    lua_pushvalue(L, 1);
    lua_pushinteger(L, (int)luaL_optnumber(L, 2, 0));
    lua_pushcclosure(L, g_events_next, 2);
    return 1;
}

static int g_pointer(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    double x = 0, y = 0;
    int b = 0;
    int rc = goome_pointer(g->g, &x, &y, &b);
    if (rc <= 0) {
        lua_pushnil(L);
        return 1;
    }
    lua_pushnumber(L, x);
    lua_pushnumber(L, y);
    lua_pushinteger(L, b);
    return 3;
}

static int g_keyboard(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    return lg_res(L, g->g, goome_keyboard(g->g, lua_isnone(L, 2) ? 1 : lg_bool(L, 2)));
}

static int g_grab(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    return lg_res(L, g->g, goome_grab(g->g, lua_isnone(L, 2) ? 1 : lg_bool(L, 2)));
}

static int g_grabbed(lua_State *L)
{
    lua_pushboolean(L, goome_grabbed(lg_gopen(L, 1)->g) > 0);
    return 1;
}

static int g_hotkey(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    return lg_res(L, g->g, goome_hotkey(g->g, luaL_checkstring(L, 2), (int)luaL_optnumber(L, 3, 1)));
}

static int l_parse_combo(lua_State *L)
{
    int key = 0, mods = 0;
    int rc = goome_parse_combo(luaL_checkstring(L, 1), &key, &mods);
    if (rc < 0) return lg_fail(L, NULL, rc);
    lua_pushinteger(L, key);
    lua_pushinteger(L, mods);
    return 2;
}

static int g_control_path(lua_State *L)
{
    const char *p = goome_control_path(lg_gopen(L, 1)->g);
    if (p) lua_pushstring(L, p);
    else lua_pushnil(L);
    return 1;
}

static int l_send(lua_State *L)
{
    return lg_res(L, NULL, goome_send(luaL_checkstring(L, 1), luaL_checkstring(L, 2)));
}

static int l_now_ms(lua_State *L)
{
    lua_pushnumber(L, (lua_Number)goome_now_ms());
    return 1;
}

static int l_pacer(lua_State *L)
{
    goome_pacer *p = (goome_pacer *)lua_newuserdata(L, sizeof(goome_pacer));
    memset(p, 0, sizeof(*p));
    p->fps = (int)luaL_optnumber(L, 1, 60);
    lg_newmt(L, MT_PACER);
    return 1;
}

static int pacer_wait(lua_State *L)
{
    goome_pacer *p = (goome_pacer *)lg_check(L, 1, MT_PACER);
    lua_pushinteger(L, goome_pace(p, (int)luaL_optnumber(L, 2, p->fps)));
    return 1;
}

static int g_mode(lua_State *L)
{
    lua_pushinteger(L, goome_mode(lg_gopen(L, 1)->g));
    return 1;
}

static int g_window_title(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    return lg_res(L, g->g, goome_window_title(g->g, luaL_checkstring(L, 2)));
}

static int g_window_size(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    return lg_res(L, g->g, goome_window_size(g->g, (int)luaL_checknumber(L, 2), (int)luaL_checknumber(L, 3)));
}

static int g_window_pos(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    int set = !lua_isnoneornil(L, 2);
    int x = set ? (int)luaL_checknumber(L, 2) : 0, y = set ? (int)luaL_checknumber(L, 3) : 0;
    int rc = goome_window_pos(g->g, &x, &y, set);
    if (rc < 0) return lg_fail(L, g->g, rc);
    lua_pushinteger(L, x);
    lua_pushinteger(L, y);
    return 2;
}

static int g_window_state(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    if (lua_isnoneornil(L, 2)) {
        lua_pushinteger(L, goome_window_get_state(g->g));
        return 1;
    }
    return lg_res(L, g->g, goome_window_state(g->g, (int)luaL_checknumber(L, 2)));
}

static int g_window_drag(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    return lg_res(L, g->g, goome_window_drag(g->g, (int)luaL_optnumber(L, 2, 0)));
}

static int g_window_show(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    return lg_res(L, g->g, goome_window_show(g->g, lua_isnone(L, 2) ? 1 : lg_bool(L, 2)));
}

static int g_cursor(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    if (lua_isnoneornil(L, 2)) {
        lua_pushinteger(L, goome_cursor_shape(g->g));
        return 1;
    }
    return lg_res(L, g->g, goome_cursor(g->g, (int)luaL_checknumber(L, 2)));
}

static int g_clipboard(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    if (!lua_isnoneornil(L, 2)) return lg_res(L, g->g, goome_clipboard_set(g->g, luaL_checkstring(L, 2)));
    char small[256];
    int n = goome_clipboard_get(g->g, small, sizeof(small));
    if (n < 0) return lg_fail(L, g->g, n);
    if (n < (int)sizeof(small)) {
        lua_pushlstring(L, small, n);
        return 1;
    }
    char *big = (char *)malloc(n + 1);
    if (!big) return lg_fail(L, g->g, GOOME_ENOMEM);
    int m = goome_clipboard_get(g->g, big, n + 1);
    lua_pushlstring(L, big, m < 0 ? 0 : (m > n ? n : m));
    free(big);
    return 1;
}

static int g_drop_path(lua_State *L)
{
    const char *p = goome_drop_path(lg_gopen(L, 1)->g);
    if (p) lua_pushstring(L, p);
    else lua_pushnil(L);
    return 1;
}

static int g_event_text(lua_State *L)
{
    lua_pushstring(L, goome_event_text(lg_gopen(L, 1)->g));
    return 1;
}

static int g_preedit_cursor(lua_State *L)
{
    lua_pushinteger(L, goome_preedit_cursor(lg_gopen(L, 1)->g));
    return 1;
}

static int g_text_input(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    goome_rect r;
    int on = lua_isnone(L, 2) ? 1 : lg_bool(L, 2);
    return lg_res(L, g->g, goome_text_input(g->g, on, lg_rect_at(L, 3, &r) ? &r : NULL));
}

static int lg_push_ime(lua_State *L, int type)
{
    lg_g *g = lg_gopen(L, 1);
    goome_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = type;
    ev.id = type == GOOME_PREEDIT ? (int)luaL_optnumber(L, 3, 0) : 0;
    const char *s = luaL_optstring(L, 2, "");
    strncpy(ev.msg, s, sizeof(ev.msg) - 1);
    return lg_res(L, g->g, goome_push(g->g, &ev));
}

static int g_push_ime(lua_State *L)
{
    return lg_push_ime(L, GOOME_TEXT);
}

static int g_push_preedit(lua_State *L)
{
    return lg_push_ime(L, GOOME_PREEDIT);
}

static int g_push(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    goome_event ev;
    if (lua_istable(L, 2)) {
        lg_ev_to(L, 2, &ev);
    } else {
        if (lua_istable(L, 3)) lg_ev_to(L, 3, &ev);
        else memset(&ev, 0, sizeof(ev));
        ev.type = (int)luaL_checknumber(L, 2);
    }
    return lg_res(L, g->g, goome_push(g->g, &ev));
}

static int g_push_text(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    size_t n;
    const unsigned char *s = (const unsigned char *)luaL_checklstring(L, 2, &n);
    for (size_t k = 0; k < n;) {
        size_t len = s[k] < 0x80 ? 1 : s[k] < 0xE0 ? 2 : s[k] < 0xF0 ? 3 : 4;
        if (k + len > n) len = n - k;
        goome_event ev;
        memset(&ev, 0, sizeof(ev));
        ev.type = GOOME_KEY;
        ev.key = len == 1 ? s[k] : 0;
        memcpy(ev.text, s + k, len);
        goome_push(g->g, &ev);
        k += len;
    }
    return 0;
}

static int g_push_click(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    goome_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.x = luaL_checknumber(L, 2);
    ev.y = luaL_checknumber(L, 3);
    ev.button = (int)luaL_optnumber(L, 4, 1);
    ev.type = GOOME_MOTION;
    goome_push(g->g, &ev);
    ev.type = GOOME_DOWN;
    goome_push(g->g, &ev);
    ev.type = GOOME_UP;
    goome_push(g->g, &ev);
    return 0;
}

static int g_resize(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    return lg_res(L, g->g, goome_resize(g->g, (int)luaL_checknumber(L, 2), (int)luaL_checknumber(L, 3), luaL_optnumber(L, 4, 0)));
}

static int g_frame(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    goome_image img;
    int rc = goome_frame(g->g, &img);
    if (rc < 0) return lg_fail(L, g->g, rc);
    return lg_push_image(L, 1, g, &img, 1);
}

static int g_hit(lua_State *L)
{
    lua_pushboolean(L, goome_hit(lg_gopen(L, 1)->g, luaL_checknumber(L, 2), luaL_checknumber(L, 3)));
    return 1;
}

static int g_frame_dirty(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    goome_rect r;
    int rc = goome_frame_dirty(g->g, &r);
    if (rc < 0) return lg_fail(L, g->g, rc);
    if (rc == 0) {
        lua_pushnil(L);
        return 1;
    }
    lg_push_rect(L, &r);
    return 1;
}

static int g_frame_copy(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    int fmt = (int)luaL_optnumber(L, 2, GOOME_FMT_BGRA_PREMUL);
    goome_rect r;
    int has = lg_rect_at(L, 3, &r);
    if (lua_islightuserdata(L, 4)) {
        int stride = (int)luaL_checknumber(L, 5);
        char *dst = (char *)lua_touserdata(L, 4);
        if (has && lg_bool(L, 6)) dst += (size_t)r.y * stride + (size_t)r.x * 4;
        return lg_res(L, g->g, goome_frame_copy(g->g, dst, stride, fmt, has ? &r : NULL));
    }
    goome_image img;
    int rc = goome_frame(g->g, &img);
    if (rc < 0) return lg_fail(L, g->g, rc);
    int w = has ? r.w : img.w, h = has ? r.h : img.h;
    if (w <= 0 || h <= 0) {
        lua_pushliteral(L, "");
        return 1;
    }
    char *buf = (char *)malloc((size_t)w * h * 4);
    if (!buf) return lg_fail(L, g->g, GOOME_ENOMEM);
    rc = goome_frame_copy(g->g, buf, w * 4, fmt, has ? &r : NULL);
    if (rc < 0) {
        free(buf);
        return lg_fail(L, g->g, rc);
    }
    lua_pushlstring(L, buf, (size_t)w * h * 4);
    free(buf);
    return 1;
}

static int lg_px_of(lua_State *L, int i, lg_px *p)
{
    lg_canvas *c;
    lg_image *im;
    lg_bmp *b;
    if ((c = (lg_canvas *)lg_test(L, i, MT_CANVAS))) {
        if (!c->c) luaL_error(L, "this canvas got handed back already");
        p->px = c->c->px, p->w = c->c->w, p->h = c->c->h, p->stride = c->c->stride, p->writable = 1;
        return 1;
    }
    if ((im = (lg_image *)lg_test(L, i, MT_IMAGE))) {
        if (!im->g->g || im->gen != (im->kind ? im->g->begin_gen : im->g->grab_gen[im->img.mon & 63]))
            luaL_error(L, "this image is gone, copy() it if you want to keep it");
        p->px = im->img.px, p->w = im->img.w, p->h = im->img.h, p->stride = im->img.stride, p->writable = 0;
        return 1;
    }
    if ((b = (lg_bmp *)lg_test(L, i, MT_BMP))) {
        if (b->closed) luaL_error(L, "this bitmap is closed");
        p->px = b->b.px, p->w = b->b.w, p->h = b->b.h, p->stride = b->b.stride, p->writable = 1;
        return 1;
    }
    if (lg_test(L, i, MT_PIX)) {
        lg_pix *v = (lg_pix *)lua_touserdata(L, i);
        lg_getref(L, v->ref);
        lg_px_of(L, lua_gettop(L), p);
        lua_pop(L, 1);
        return 1;
    }
    return 0;
}

static void lg_px_check(lua_State *L, int i, lg_px *p)
{
    if (!lg_px_of(L, i, p)) luaL_error(L, "bad argument #%d, wanted something with pixels", i);
}

static int lg_pixels(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    lg_pix *v = (lg_pix *)lua_newuserdata(L, sizeof(lg_pix));
    v->ref = lg_ref(L, 1);
    lg_newmt(L, MT_PIX);
    return 1;
}

static int pix_gc(lua_State *L)
{
    lg_pix *v = (lg_pix *)lua_touserdata(L, 1);
    lg_unref(L, &v->ref);
    return 0;
}

static uint32_t fnv_rows(const lg_px *p)
{
    uint32_t v = 2166136261u;
    for (int y = 0; y < p->h; y++) {
        const uint32_t *r = p->px + (size_t)y * p->stride;
        for (int x = 0; x < p->w; x++) {
            uint32_t c = r[x];
            for (int k = 0; k < 4; k++) v = (v ^ ((c >> (k * 8)) & 255)) * 16777619u;
        }
    }
    return v;
}

static int lg_hash(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    int w = (int)luaL_optnumber(L, 2, p.w), h = (int)luaL_optnumber(L, 3, p.h);
    if (w < 0 || w > p.stride || h < 0 || h > p.h) return luaL_error(L, "cant hash %dx%d of %dx%d stride %d", w, h, p.w, p.h, p.stride);
    p.w = w, p.h = h;
    lua_pushnumber(L, (lua_Number)fnv_rows(&p));
    return 1;
}

static int lg_pixel(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    int x = (int)luaL_checknumber(L, 2), y = (int)luaL_checknumber(L, 3);
    if (x < 0 || y < 0 || x >= p.stride || y >= p.h) return luaL_error(L, "%d,%d is outside %dx%d", x, y, p.stride, p.h);
    lua_pushnumber(L, (lua_Number)p.px[(size_t)y * p.stride + x]);
    return 1;
}

static int lg_set_pixel(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    int x = (int)luaL_checknumber(L, 2), y = (int)luaL_checknumber(L, 3);
    if (!p.writable) return luaL_error(L, "these pixels are read only");
    if (x < 0 || y < 0 || x >= p.stride || y >= p.h) return luaL_error(L, "%d,%d is outside %dx%d", x, y, p.stride, p.h);
    p.px[(size_t)y * p.stride + x] = lg_u32(L, 4);
    return 0;
}

static int lg_ptr(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    lua_pushlightuserdata(L, p.px);
    return 1;
}

static int lg_bytes(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    for (int y = 0; y < p.h; y++) luaL_addlstring(&b, (const char *)(p.px + (size_t)y * p.stride), (size_t)p.w * 4);
    luaL_pushresult(&b);
    return 1;
}

static int lg_save_ppm_obj(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    return lg_res(L, NULL, goome_save_ppm(luaL_checkstring(L, 2), p.px, p.w, p.h, p.stride));
}

static int pix_index(lua_State *L)
{
    if (lua_isnumber(L, 2)) {
        lg_px p;
        lg_px_check(L, 1, &p);
        long i = (long)lua_tonumber(L, 2);
        if (i < 0 || i >= (long)p.h * p.stride) {
            lua_pushnil(L);
            return 1;
        }
        lua_pushnumber(L, (lua_Number)p.px[i]);
        return 1;
    }
    const char *k = luaL_checkstring(L, 2);
    if (!strcmp(k, "w") || !strcmp(k, "h") || !strcmp(k, "stride")) {
        lg_px p;
        lg_px_check(L, 1, &p);
        lua_pushinteger(L, k[0] == 'w' ? p.w : k[0] == 'h' ? p.h : p.stride);
        return 1;
    }
    lua_pushvalue(L, 2);
    lua_rawget(L, lua_upvalueindex(1));
    return 1;
}

static int pix_newindex(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    long i = (long)luaL_checknumber(L, 2);
    if (!p.writable) return luaL_error(L, "these pixels are read only");
    if (i < 0 || i >= (long)p.h * p.stride) return luaL_error(L, "index %d is outside the pixels", (int)i);
    p.px[i] = lg_u32(L, 3);
    return 0;
}

static int pix_len(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    lua_pushinteger(L, p.h * p.stride);
    return 1;
}

static int pix_fill(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    if (!p.writable) return luaL_error(L, "these pixels are read only");
    uint32_t v = lg_optu32(L, 2, 0);
    for (long i = 0; i < (long)p.h * p.stride; i++) p.px[i] = v;
    return 0;
}

static int l_canvas_new(lua_State *L)
{
    int w = (int)luaL_checknumber(L, 1), h = (int)luaL_checknumber(L, 2);
    int stride = (int)luaL_optnumber(L, 3, w);
    if (w < 0 || h < 0 || stride < w) return luaL_error(L, "bad canvas size %dx%d stride %d", w, h, stride);
    double scale = luaL_optnumber(L, 4, 1.0), ox = luaL_optnumber(L, 5, 0), oy = luaL_optnumber(L, 6, 0);
    lg_canvas *c = (lg_canvas *)lua_newuserdata(L, sizeof(lg_canvas));
    memset(c, 0, sizeof(*c));
    lg_newmt(L, MT_CANVAS);
    size_t n = (size_t)(h * stride > 0 ? h * stride : 1);
    c->buf = (uint32_t *)calloc(n, 4);
    if (!c->buf) return luaL_error(L, "out of memory");
    c->own.px = c->buf, c->own.w = w, c->own.h = h, c->own.stride = stride;
    c->own.scale = scale, c->own.ox = ox, c->own.oy = oy;
    c->c = &c->own;
    return 1;
}

static int cv_gc(lua_State *L)
{
    lg_canvas *c = (lg_canvas *)lua_touserdata(L, 1);
    free(c->buf);
    free(c->hits);
    c->buf = NULL, c->hits = NULL, c->c = NULL;
    return 0;
}

static int cv_valid(lua_State *L)
{
    lua_pushboolean(L, ((lg_canvas *)lg_check(L, 1, MT_CANVAS))->c != NULL);
    return 1;
}

static int cv_clear(lua_State *L)
{
    goome_clear(lg_cv(L, 1)->c);
    return 0;
}

#define N(i) luaL_checknumber(L, i)

static int cv_rect(lua_State *L)
{
    goome_draw_rect(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5), lg_u32(L, 6));
    return 0;
}

static int cv_round_rect(lua_State *L)
{
    goome_draw_round_rect(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5), N(6), lg_u32(L, 7));
    return 0;
}

static int cv_frame(lua_State *L)
{
    goome_draw_frame(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5), N(6), lg_u32(L, 7));
    return 0;
}

static int cv_line(lua_State *L)
{
    goome_draw_line(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5), N(6), lg_u32(L, 7));
    return 0;
}

static int cv_triangle(lua_State *L)
{
    goome_draw_triangle(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5), N(6), N(7), lg_u32(L, 8));
    return 0;
}

static uint32_t *lg_argb_arg(lua_State *L, int i, int n, int *tmp, int *stride)
{
    *tmp = 0;
    if (stride) *stride = 0;
    lg_px p;
    if (lg_px_of(L, i, &p)) {
        if (stride) *stride = p.stride;
        return p.px;
    }
    uint32_t *a = (uint32_t *)malloc(sizeof(uint32_t) * (n > 0 ? n : 1));
    if (!a) luaL_error(L, "out of memory");
    *tmp = 1;
    if (lua_type(L, i) == LUA_TSTRING) {
        size_t len;
        const unsigned char *s = (const unsigned char *)lua_tolstring(L, i, &len);
        if ((int)len < n * 4) {
            free(a);
            luaL_error(L, "wanted %d bytes of BGRA, got %d", n * 4, (int)len);
        }
        for (int k = 0; k < n; k++) a[k] = s[k * 4] | s[k * 4 + 1] << 8 | s[k * 4 + 2] << 16 | (uint32_t)s[k * 4 + 3] << 24;
        return a;
    }
    if (!lua_istable(L, i)) {
        free(a);
        luaL_error(L, "bad argument #%d, wanted pixels, a table or a string", i);
    }
    if (LG_LEN(L, i) < n) {
        free(a);
        luaL_error(L, "wanted %d pixels, got %d", n, LG_LEN(L, i));
    }
    for (int k = 0; k < n; k++) {
        lua_rawgeti(L, i, k + 1);
        a[k] = lg_u32(L, -1);
        lua_pop(L, 1);
    }
    return a;
}

static int cv_image(lua_State *L)
{
    lg_canvas *c = lg_cv(L, 1);
    int iw = (int)N(7), ih = (int)N(8), tmp, stride;
    uint32_t *px = lg_argb_arg(L, 6, iw * ih, &tmp, &stride);
    if (!tmp && stride != iw) return luaL_error(L, "image() wants pixels with stride == width");
    goome_draw_image(c->c, N(2), N(3), N(4), N(5), px, iw, ih);
    if (tmp) free(px);
    return 0;
}

static int cv_erase(lua_State *L)
{
    goome_erase(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5));
    return 0;
}

static int cv_text(lua_State *L)
{
    lua_pushnumber(L, goome_draw_text(lg_cv(L, 1)->c, N(2), N(3), luaL_checkstring(L, 4), lg_bool(L, 6), lg_optu32(L, 5, 0xFFFFFFFF)));
    return 1;
}

static int cv_text_width(lua_State *L)
{
    lua_pushnumber(L, goome_text_width(lg_cv(L, 1)->c, luaL_checkstring(L, 2), lg_bool(L, 3)));
    return 1;
}

static int cv_blit(lua_State *L)
{
    lg_canvas *d = lg_cv(L, 1), *s = lg_cv(L, 2);
    goome_canvas_blit(d->c, s->c, luaL_optnumber(L, 3, 1), luaL_optnumber(L, 4, 0), luaL_optnumber(L, 5, 0));
    return 0;
}

static goome_radii lg_radii(lua_State *L, int i)
{
    if (lua_istable(L, i)) {
        goome_radii r;
        double v[4];
        for (int k = 0; k < 4; k++) {
            lua_rawgeti(L, i, k + 1);
            v[k] = lua_tonumber(L, -1);
            lua_pop(L, 1);
        }
        r.tl = lg_fnum(L, i, "tl", v[0]);
        r.tr = lg_fnum(L, i, "tr", v[1]);
        r.br = lg_fnum(L, i, "br", v[2]);
        r.bl = lg_fnum(L, i, "bl", v[3]);
        return r;
    }
    return goome_radius(luaL_optnumber(L, i, 0));
}

static int l_radius(lua_State *L)
{
    goome_radii r = goome_radius(luaL_checknumber(L, 1));
    lua_createtable(L, 4, 0);
    lua_pushnumber(L, r.tl);
    lua_rawseti(L, -2, 1);
    lua_pushnumber(L, r.tr);
    lua_rawseti(L, -2, 2);
    lua_pushnumber(L, r.br);
    lua_rawseti(L, -2, 3);
    lua_pushnumber(L, r.bl);
    lua_rawseti(L, -2, 4);
    return 1;
}

static int cv_clip_push(lua_State *L)
{
    goome_clip_push(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5));
    return 0;
}

static int cv_clip_pop(lua_State *L)
{
    goome_clip_pop(lg_cv(L, 1)->c);
    return 0;
}

static int cv_rrect(lua_State *L)
{
    goome_draw_rrect(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5), lg_radii(L, 6), lg_u32(L, 7));
    return 0;
}

static int cv_rrect_line(lua_State *L)
{
    goome_draw_rrect_line(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5), lg_radii(L, 6), N(7), lg_u32(L, 8));
    return 0;
}

static int cv_rrect_grad(lua_State *L)
{
    goome_draw_rrect_grad(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5), lg_radii(L, 6), lg_u32(L, 7), lg_u32(L, 8), lg_bool(L, 9));
    return 0;
}

static int cv_shadow(lua_State *L)
{
    goome_draw_shadow(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5), N(6), N(7), lg_u32(L, 8));
    return 0;
}

static int cv_circle(lua_State *L)
{
    goome_draw_circle(lg_cv(L, 1)->c, N(2), N(3), N(4), lg_u32(L, 5));
    return 0;
}

static int cv_ring(lua_State *L)
{
    goome_draw_ring(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5), lg_u32(L, 6));
    return 0;
}

static int cv_arc(lua_State *L)
{
    goome_draw_arc(lg_cv(L, 1)->c, N(2), N(3), N(4), N(5), N(6), N(7), lg_u32(L, 8));
    return 0;
}

static int cv_poly(lua_State *L)
{
    lg_canvas *c = lg_cv(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int n = LG_LEN(L, 2);
    lua_rawgeti(L, 2, 1);
    int pairs = lua_istable(L, -1);
    lua_pop(L, 1);
    int pts = pairs ? n : n / 2;
    double *xy = (double *)malloc(sizeof(double) * 2 * (pts > 0 ? pts : 1));
    if (!xy) return luaL_error(L, "out of memory");
    for (int k = 0; k < pts; k++) {
        if (pairs) {
            lua_rawgeti(L, 2, k + 1);
            lua_rawgeti(L, -1, 1);
            xy[k * 2] = lua_tonumber(L, -1);
            lua_rawgeti(L, -2, 2);
            xy[k * 2 + 1] = lua_tonumber(L, -1);
            lua_pop(L, 3);
        } else {
            lua_rawgeti(L, 2, k * 2 + 1);
            xy[k * 2] = lua_tonumber(L, -1);
            lua_rawgeti(L, 2, k * 2 + 2);
            xy[k * 2 + 1] = lua_tonumber(L, -1);
            lua_pop(L, 2);
        }
    }
    goome_draw_poly(c->c, xy, pts, lg_u32(L, 3));
    free(xy);
    return 0;
}

static lg_bmp *lg_bm(lua_State *L, int i)
{
    lg_bmp *b = (lg_bmp *)lg_check(L, i, MT_BMP);
    if (b->closed) luaL_error(L, "this bitmap is closed");
    return b;
}

static lg_bmp *lg_optbm(lua_State *L, int i)
{
    return lua_isnoneornil(L, i) ? NULL : lg_bm(L, i);
}

static int cv_bitmap(lua_State *L)
{
    lg_canvas *c = lg_cv(L, 1);
    lg_bmp *b = lg_bm(L, 2);
    goome_draw_bitmap(c->c, &b->b, N(3), N(4), N(5), N(6), lg_radii(L, 7), lg_optu32(L, 8, 0xFFFFFFFF));
    return 0;
}

static int cv_bitmap_part(lua_State *L)
{
    lg_canvas *c = lg_cv(L, 1);
    lg_bmp *b = lg_bm(L, 2);
    goome_draw_bitmap_part(c->c, &b->b, (int)N(3), (int)N(4), (int)N(5), (int)N(6), N(7), N(8), N(9), N(10), lg_optu32(L, 11, 0xFFFFFFFF));
    return 0;
}

static int cv_bitmap_nine(lua_State *L)
{
    lg_canvas *c = lg_cv(L, 1);
    lg_bmp *b = lg_bm(L, 2);
    double l = N(7);
    goome_draw_bitmap_nine(c->c, &b->b, N(3), N(4), N(5), N(6), l, luaL_optnumber(L, 8, l), luaL_optnumber(L, 9, l), luaL_optnumber(L, 10, l));
    return 0;
}

static goome_font *lg_optfont(lua_State *L, int i);

static int cv_font_text(lua_State *L)
{
    lg_canvas *c = lg_cv(L, 1);
    goome_font *f = lg_optfont(L, 2);
    lua_pushnumber(L, goome_text(c->c, f, N(3), N(4), N(5), luaL_checkstring(L, 6), lg_optu32(L, 7, 0xFFFFFFFF)));
    return 1;
}

static int cv_damage(lua_State *L)
{
    lg_canvas *c = lg_cv(L, 1);
    goome_rect r;
    if (lg_rect_at(L, 2, &r)) goome_damage(c->c, &r);
    else goome_damage(c->c, NULL);
    return 0;
}

static int cv_hit(lua_State *L)
{
    lg_add_hit(lg_cv(L, 1), N(2), N(3), N(4), N(5));
    return 0;
}

typedef struct {
    const char *name;
    int off, kind;
} lg_field;

enum { K_INT, K_DBL, K_U32, K_FONT, K_SKIN, K_BOOL };

#define CF(f, k) {#f, (int)offsetof(goome_canvas, f), k}
static const lg_field cv_fields[] = {
    CF(w, K_INT), CF(h, K_INT), CF(stride, K_INT), CF(ox, K_DBL), CF(oy, K_DBL), CF(scale, K_DBL), CF(mon, K_INT),
    CF(dx0, K_INT), CF(dy0, K_INT), CF(dx1, K_INT), CF(dy1, K_INT), CF(cx0, K_INT), CF(cy0, K_INT), CF(cx1, K_INT), CF(cy1, K_INT),
    CF(kx0, K_INT), CF(ky0, K_INT), CF(kx1, K_INT), CF(ky1, K_INT), CF(nclip, K_INT), {NULL, 0, 0},
};

static const lg_field *lg_find(const lg_field *f, const char *k)
{
    for (; f->name; f++)
        if (!strcmp(f->name, k)) return f;
    return NULL;
}

static int lg_get_plain(lua_State *L, void *base, const lg_field *f)
{
    char *p = (char *)base + f->off;
    switch (f->kind) {
    case K_INT: lua_pushinteger(L, *(int *)p); return 1;
    case K_BOOL: lua_pushboolean(L, *(int *)p); return 1;
    case K_DBL: lua_pushnumber(L, *(double *)p); return 1;
    case K_U32: lua_pushnumber(L, (lua_Number) * (uint32_t *)p); return 1;
    }
    return 0;
}

static int lg_set_plain(lua_State *L, void *base, const lg_field *f, int i)
{
    char *p = (char *)base + f->off;
    switch (f->kind) {
    case K_INT: *(int *)p = (int)luaL_checknumber(L, i); return 1;
    case K_BOOL: *(int *)p = lg_bool(L, i); return 1;
    case K_DBL: *(double *)p = luaL_checknumber(L, i); return 1;
    case K_U32: *(uint32_t *)p = lg_u32(L, i); return 1;
    }
    return 0;
}

static int lg_methods_first(lua_State *L)
{
    lua_pushvalue(L, 2);
    lua_rawget(L, lua_upvalueindex(1));
    return !lua_isnil(L, -1);
}

static int cv_index(lua_State *L)
{
    if (lg_methods_first(L)) return 1;
    lg_canvas *c = (lg_canvas *)lua_touserdata(L, 1);
    const char *k = lua_tostring(L, 2);
    const lg_field *f = k ? lg_find(cv_fields, k) : NULL;
    if (!f) return 0;
    if (!c->c) return luaL_error(L, "this canvas got handed back already");
    return lg_get_plain(L, c->c, f);
}

static int cv_newindex(lua_State *L)
{
    lg_canvas *c = lg_cv(L, 1);
    const lg_field *f = lg_find(cv_fields, luaL_checkstring(L, 2));
    if (!f) return luaL_error(L, "canvas has no field %s", lua_tostring(L, 2));
    lg_set_plain(L, c->c, f, 3);
    return 0;
}

static int im_gc(lua_State *L)
{
    lg_image *im = (lg_image *)lua_touserdata(L, 1);
    lg_unref(L, &im->gref);
    return 0;
}

static int im_index(lua_State *L)
{
    if (lg_methods_first(L)) return 1;
    lg_image *im = (lg_image *)lua_touserdata(L, 1);
    const char *k = lua_tostring(L, 2);
    if (!k) return 0;
    if (!strcmp(k, "fresh")) {
        lua_pushboolean(L, im->g->g && im->gen == (im->kind ? im->g->begin_gen : im->g->grab_gen[im->img.mon & 63]));
        return 1;
    }
    if (!strcmp(k, "w")) lua_pushinteger(L, im->img.w);
    else if (!strcmp(k, "h")) lua_pushinteger(L, im->img.h);
    else if (!strcmp(k, "stride")) lua_pushinteger(L, im->img.stride);
    else if (!strcmp(k, "mon")) lua_pushinteger(L, im->img.mon);
    else if (!strcmp(k, "has_self")) lua_pushboolean(L, im->img.has_self);
    else if (!strcmp(k, "has_cursor")) lua_pushboolean(L, im->img.has_cursor);
    else if (!strcmp(k, "area")) lg_push_rect(L, &im->img.area);
    else if (!strcmp(k, "cursor")) lg_push_rect(L, &im->img.cursor);
    else return 0;
    return 1;
}

static int lg_push_bmp(lua_State *L, const goome_bitmap *src)
{
    lg_bmp *b = (lg_bmp *)lua_newuserdata(L, sizeof(lg_bmp));
    memset(b, 0, sizeof(*b));
    b->b = *src;
    b->keep = LUA_NOREF;
    lg_newmt(L, MT_BMP);
    return 1;
}

static int im_copy(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    goome_bitmap b;
    uint32_t *tight = (uint32_t *)malloc(sizeof(uint32_t) * (size_t)(p.w * p.h > 0 ? p.w * p.h : 1));
    if (!tight) return luaL_error(L, "out of memory");
    for (int y = 0; y < p.h; y++) memcpy(tight + (size_t)y * p.w, p.px + (size_t)y * p.stride, (size_t)p.w * 4);
    int rc = goome_bitmap_from_argb(tight, p.w, p.h, &b);
    free(tight);
    if (rc < 0) return lg_fail(L, NULL, rc);
    return lg_push_bmp(L, &b);
}

static void lg_bmp_free(lua_State *L, lg_bmp *b)
{
    if (b->b.owned) goome_bitmap_free(&b->b);
    memset(&b->b, 0, sizeof(b->b));
    lg_unref(L, &b->keep);
}

static int bmp_close(lua_State *L)
{
    lg_bmp *b = (lg_bmp *)lg_check(L, 1, MT_BMP);
    if (b->closed) return 0;
    b->closed = 1;
    if (!b->users) lg_bmp_free(L, b);
    return 0;
}

static int bmp_gc(lua_State *L)
{
    lg_bmp *b = (lg_bmp *)lua_touserdata(L, 1);
    b->closed = 1;
    lg_bmp_free(L, b);
    return 0;
}

static int bmp_index(lua_State *L)
{
    if (lg_methods_first(L)) return 1;
    lg_bmp *b = (lg_bmp *)lua_touserdata(L, 1);
    const char *k = lua_tostring(L, 2);
    if (!k) return 0;
    if (!strcmp(k, "closed")) {
        lua_pushboolean(L, b->closed);
        return 1;
    }
    if (b->closed) return luaL_error(L, "this bitmap is closed");
    if (!strcmp(k, "w")) lua_pushinteger(L, b->b.w);
    else if (!strcmp(k, "h")) lua_pushinteger(L, b->b.h);
    else if (!strcmp(k, "stride")) lua_pushinteger(L, b->b.stride);
    else if (!strcmp(k, "owned")) lua_pushboolean(L, b->b.owned);
    else return 0;
    return 1;
}

static int lg_bmp_result(lua_State *L, int rc, goome_bitmap *b)
{
    if (rc < 0) {
        const char *e = goome_bitmap_error();
        lua_pushnil(L);
        lua_pushstring(L, e && *e ? e : goome_strerror(rc));
        lua_pushinteger(L, rc);
        return 3;
    }
    return lg_push_bmp(L, b);
}

static int l_bitmap_load(lua_State *L)
{
    goome_bitmap b;
    return lg_bmp_result(L, goome_bitmap_load(luaL_checkstring(L, 1), &b), &b);
}

static int l_bitmap_from_bytes(lua_State *L)
{
    size_t n;
    const char *s = luaL_checklstring(L, 1, &n);
    goome_bitmap b;
    return lg_bmp_result(L, goome_bitmap_load_mem(s, n, &b), &b);
}

static int l_bitmap_from_argb(lua_State *L)
{
    int w = (int)N(2), h = (int)N(3), tmp, stride;
    if (w <= 0 || h <= 0) return luaL_error(L, "bad bitmap size %dx%d", w, h);
    uint32_t *px = lg_argb_arg(L, 1, w * h, &tmp, &stride);
    goome_bitmap b;
    int rc;
    if (!tmp && stride != w) {
        uint32_t *t = (uint32_t *)malloc(sizeof(uint32_t) * (size_t)w * h);
        if (!t) return luaL_error(L, "out of memory");
        for (int y = 0; y < h; y++) memcpy(t + (size_t)y * w, px + (size_t)y * stride, (size_t)w * 4);
        rc = goome_bitmap_from_argb(t, w, h, &b);
        free(t);
    } else {
        rc = goome_bitmap_from_argb(px, w, h, &b);
    }
    if (tmp) free(px);
    return lg_bmp_result(L, rc, &b);
}

static int l_bitmap_wrap(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 1, &p);
    int w = (int)luaL_optnumber(L, 2, p.w), h = (int)luaL_optnumber(L, 3, p.h), stride = (int)luaL_optnumber(L, 4, p.stride);
    if (w > stride || (size_t)h * stride > (size_t)p.h * p.stride) return luaL_error(L, "%dx%d stride %d doesnt fit in those pixels", w, h, stride);
    goome_bitmap b;
    memset(&b, 0, sizeof(b));
    b.px = p.px, b.w = w, b.h = h, b.stride = stride;
    lg_push_bmp(L, &b);
    lg_bmp *nb = (lg_bmp *)lua_touserdata(L, -1);
    nb->keep = lg_ref(L, 1);
    return 1;
}

static int l_bitmap_error(lua_State *L)
{
    const char *e = goome_bitmap_error();
    lua_pushstring(L, e ? e : "");
    return 1;
}

static lg_font *lg_ft(lua_State *L, int i)
{
    lg_font *f = (lg_font *)lg_check(L, i, MT_FONT);
    if (f->closed) luaL_error(L, "this font is closed");
    return f;
}

static goome_font *lg_optfont(lua_State *L, int i)
{
    return lua_isnoneornil(L, i) ? NULL : lg_ft(L, i)->f;
}

static int lg_push_font(lua_State *L, goome_font *gf, const char *what)
{
    if (!gf) {
        lua_pushnil(L);
        lua_pushfstring(L, "couldnt load the font %s", what);
        lua_pushinteger(L, GOOME_EARG);
        return 3;
    }
    lg_font *f = (lg_font *)lua_newuserdata(L, sizeof(lg_font));
    memset(f, 0, sizeof(*f));
    f->f = gf;
    lg_newmt(L, MT_FONT);
    lua_newtable(L);
    LG_SETUV(L, -2);
    return 1;
}

static int l_font_load(lua_State *L)
{
    const char *p = luaL_checkstring(L, 1);
    goome_font *f = lua_isnoneornil(L, 2) ? goome_font_load(p) : goome_font_load_index(p, (int)N(2));
    return lg_push_font(L, f, p);
}

static int l_font_from_bytes(lua_State *L)
{
    size_t n;
    const char *s = luaL_checklstring(L, 1, &n);
    return lg_push_font(L, goome_font_load_mem(s, n, 1), "from those bytes");
}

static int l_font_system(lua_State *L)
{
    goome_font *f = goome_font_system(luaL_optstring(L, 1, NULL));
    if (!f) {
        lua_pushnil(L);
        return 1;
    }
    return lg_push_font(L, f, "");
}

static void lg_font_free(lg_font *f)
{
    if (f->f) goome_font_free(f->f);
    f->f = NULL;
    int n = f->nfb;
    f->nfb = 0;
    for (int i = 0; i < n; i++)
        if (--f->fb[i]->users == 0 && f->fb[i]->closed) lg_font_free(f->fb[i]);
}

static int font_close(lua_State *L)
{
    lg_font *f = (lg_font *)lg_check(L, 1, MT_FONT);
    if (f->closed) return 0;
    f->closed = 1;
    if (!f->users) lg_font_free(f);
    return 0;
}

static int font_gc(lua_State *L)
{
    lg_font *f = (lg_font *)lua_touserdata(L, 1);
    f->closed = 1;
    lg_font_free(f);
    return 0;
}

static int font_measure(lua_State *L)
{
    lg_font *f = lg_ft(L, 1);
    double h = 0;
    double w = goome_text_measure(f->f, N(3), luaL_checkstring(L, 2), &h);
    lua_pushnumber(L, w);
    lua_pushnumber(L, h);
    return 2;
}

static int font_width(lua_State *L)
{
    lg_font *f = lg_ft(L, 1);
    lua_pushnumber(L, goome_text_measure(f->f, N(3), luaL_checkstring(L, 2), NULL));
    return 1;
}

static int font_line_height(lua_State *L)
{
    lua_pushnumber(L, goome_text_line_height(lg_ft(L, 1)->f, N(2)));
    return 1;
}

static int font_fallback(lua_State *L)
{
    lg_font *f = lg_ft(L, 1), *fb = lg_ft(L, 2);
    lua_settop(L, 2);
    if (fb == f || f->nfb >= 8) return 1;
    for (int i = 0; i < f->nfb; i++)
        if (f->fb[i] == fb) {
            lua_settop(L, 1);
            return 1;
        }
    goome_font_fallback(f->f, fb->f);
    f->fb[f->nfb++] = fb;
    fb->users++;
    LG_GETUV(L, 1);
    lua_pushvalue(L, 2);
    lua_rawseti(L, -2, f->nfb);
    lua_settop(L, 1);
    return 1;
}

static int font_index(lua_State *L)
{
    if (lg_methods_first(L)) return 1;
    const char *k = lua_tostring(L, 2);
    if (k && !strcmp(k, "closed")) {
        lua_pushboolean(L, ((lg_font *)lua_touserdata(L, 1))->closed);
        return 1;
    }
    return 0;
}

static int l_measure(lua_State *L)
{
    double h = 0;
    double w = goome_text_measure(NULL, luaL_optnumber(L, 2, 12), luaL_checkstring(L, 1), &h);
    lua_pushnumber(L, w);
    lua_pushnumber(L, h);
    return 2;
}

static int l_line_height(lua_State *L)
{
    lua_pushnumber(L, goome_text_line_height(NULL, luaL_optnumber(L, 1, 12)));
    return 1;
}

static int l_set_font(lua_State *L)
{
    goome_set_font((int)N(1));
    return 0;
}

static int l_text_dir(lua_State *L)
{
    static const char *const dirs[] = {"auto", "ltr", "rtl", NULL};
    goome_text_dir(lg_named(L, 1, dirs, GOOME_DIR_AUTO));
    return 0;
}

static int l_ease(lua_State *L)
{
    lua_pushnumber(L, goome_ease((int)N(1), N(2)));
    return 1;
}

static int l_font_count(lua_State *L)
{
    lua_pushinteger(L, goome_font_count());
    return 1;
}

static int l_strerror(lua_State *L)
{
    lua_pushstring(L, goome_strerror((int)N(1)));
    return 1;
}

static int l_save_ppm(lua_State *L)
{
    lg_px p;
    lg_px_check(L, 2, &p);
    return lg_res(L, NULL, goome_save_ppm(luaL_checkstring(L, 1), p.px, p.w, p.h, p.stride));
}

static void lg_retain(lua_State *L, int refs, const char *slot, int i)
{
    lg_getref(L, refs);
    lua_getfield(L, -1, slot);
    lg_bmp *ob = (lg_bmp *)lg_test(L, -1, MT_BMP);
    lg_font *of = ob ? NULL : (lg_font *)lg_test(L, -1, MT_FONT);
    if (ob && --ob->users == 0 && ob->closed) lg_bmp_free(L, ob);
    if (of && --of->users == 0 && of->closed) lg_font_free(of);
    lua_pop(L, 1);
    if (i && !lua_isnoneornil(L, i)) {
        lg_bmp *nb = (lg_bmp *)lg_test(L, i, MT_BMP);
        lg_font *nf = nb ? NULL : (lg_font *)lg_test(L, i, MT_FONT);
        if (nb) nb->users++;
        if (nf) nf->users++;
        lua_pushvalue(L, i);
    } else {
        lua_pushnil(L);
    }
    lua_setfield(L, -2, slot);
    lua_pop(L, 1);
}

static void lg_release_all(lua_State *L, int refs)
{
    lg_getref(L, refs);
    lua_pushnil(L);
    while (lua_next(L, -2)) {
        lg_bmp *b = (lg_bmp *)lg_test(L, -1, MT_BMP);
        lg_font *f = b ? NULL : (lg_font *)lg_test(L, -1, MT_FONT);
        if (b && --b->users == 0 && b->closed) lg_bmp_free(L, b);
        if (f && --f->users == 0 && f->closed) lg_font_free(f);
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
    lua_newtable(L);
    lua_rawseti(L, LUA_REGISTRYINDEX, refs);
}

static int lg_frame_keep(lua_State *L, lg_ui *u, int i)
{
    if (i < 0) i = lua_gettop(L) + i + 1;
    lg_getref(L, u->live);
    lua_pushvalue(L, i);
    lua_rawseti(L, -2, LG_LEN(L, -2) + 1);
    lua_pop(L, 1);
    return 0;
}

static void lg_ui_free(lua_State *L, lg_ui *u)
{
    if (!u->u) return;
    while (u->nw > 0) lg_win_pop(L, u, 0);
    lg_drop_live(L, u->live);
    goome_ui_free(u->u);
    u->u = NULL;
    lg_release_all(L, u->refs);
    lg_unref(L, &u->ease_ref);
    free(u->mask);
    u->mask = NULL;
    if (u->g) {
        lg_ui **p = &u->g->uis;
        while (*p && *p != u) p = &(*p)->next;
        if (*p) *p = u->next;
    }
    u->g = NULL;
}

static lg_ui *lg_uiopen(lua_State *L, int i)
{
    lg_ui *u = (lg_ui *)lg_check(L, i, MT_UI);
    if (!u->u) luaL_error(L, "this ui is closed");
    u->L = L;
    return u;
}

static int g_ui(lua_State *L)
{
    lg_g *g = lg_gopen(L, 1);
    goome_ui *gu = goome_ui_new(g->g);
    if (!gu) return lg_fail(L, g->g, GOOME_ENOMEM);
    lg_ui *u = (lg_ui *)lua_newuserdata(L, sizeof(lg_ui));
    memset(u, 0, sizeof(*u));
    u->u = gu;
    u->g = g;
    u->L = L;
    u->gref = lg_ref(L, 1);
    u->ease_ref = LUA_NOREF;
    lua_newtable(L);
    u->refs = luaL_ref(L, LUA_REGISTRYINDEX);
    lua_newtable(L);
    u->live = luaL_ref(L, LUA_REGISTRYINDEX);
    u->next = g->uis;
    g->uis = u;
    lg_newmt(L, MT_UI);
    return 1;
}

static int ui_close(lua_State *L)
{
    lg_ui *u = (lg_ui *)lg_check(L, 1, MT_UI);
    lg_ui_free(L, u);
    return 0;
}

static int ui_gc(lua_State *L)
{
    lg_ui *u = (lg_ui *)lua_touserdata(L, 1);
    lg_ui_free(L, u);
    lg_unref(L, &u->gref);
    lg_unref(L, &u->refs);
    lg_unref(L, &u->live);
    return 0;
}

static int ui_closed(lua_State *L)
{
    lua_pushboolean(L, ((lg_ui *)lg_check(L, 1, MT_UI))->u == NULL);
    return 1;
}

static int ui_feed(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    goome_event ev;
    lg_ev_to(L, 2, &ev);
    lua_pushboolean(L, goome_ui_feed(u->u, &ev));
    return 1;
}

static int ui_begin(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    if (u->g) u->g->begin_gen++;
    goome_canvas *c = goome_ui_begin(u->u, (int)luaL_optnumber(L, 2, 0));
    if (!c) {
        lua_pushnil(L);
        return 1;
    }
    return lg_push_canvas(L, c, u->live);
}

static int ui_end(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    goome_ui_end(u->u);
    while (u->nw > 0) lg_win_pop(L, u, 1);
    lg_drop_live(L, u->live);
    return 0;
}

static int ui_hit(lua_State *L)
{
    goome_ui_hit(lg_uiopen(L, 1)->u, N(2), N(3), N(4), N(5));
    return 0;
}

static int ui_animating(lua_State *L)
{
    lua_pushboolean(L, goome_ui_animating(lg_uiopen(L, 1)->u));
    return 1;
}

static int ui_wants(lua_State *L)
{
    lua_pushinteger(L, goome_ui_wants(lg_uiopen(L, 1)->u));
    return 1;
}

static int ui_wants_mouse(lua_State *L)
{
    lua_pushboolean(L, (goome_ui_wants(lg_uiopen(L, 1)->u) & GOOME_WANT_MOUSE) != 0);
    return 1;
}

static int ui_wants_keyboard(lua_State *L)
{
    lua_pushboolean(L, (goome_ui_wants(lg_uiopen(L, 1)->u) & GOOME_WANT_KEYBOARD) != 0);
    return 1;
}

static int ui_auto_grab(lua_State *L)
{
    goome_ui_auto_grab(lg_uiopen(L, 1)->u, (int)N(2));
    return 0;
}

static void lg_win_out(lua_State *L, const lg_win *ws, int t)
{
    lua_pushnumber(L, ws->x);
    lua_setfield(L, t, "x");
    lua_pushnumber(L, ws->y);
    lua_setfield(L, t, "y");
    lua_pushnumber(L, ws->w);
    lua_setfield(L, t, "w");
    lua_pushnumber(L, ws->h);
    lua_setfield(L, t, "h");
    lua_pushboolean(L, ws->open);
    lua_setfield(L, t, "open");
}

static void lg_win_pop(lua_State *L, lg_ui *u, int write)
{
    if (u->nw <= 0) return;
    u->nw--;
    if (write) {
        lg_getref(L, u->wref[u->nw]);
        lg_win_out(L, u->wst[u->nw], lua_gettop(L));
        lua_pop(L, 1);
    }
    lg_unref(L, &u->wref[u->nw]);
}

static int ui_window(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    const char *title = luaL_checkstring(L, 2);
    luaL_checktype(L, 3, LUA_TTABLE);
    int flags = (int)luaL_optnumber(L, 4, GOOME_WIN_MOVE | GOOME_WIN_COLLAPSE);
    lg_getref(L, u->refs);
    lua_getfield(L, -1, "windows");
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_pushvalue(L, -1);
        lua_setfield(L, -3, "windows");
    }
    lua_getfield(L, -1, title);
    lg_win *ws = (lg_win *)lua_touserdata(L, -1);
    if (!ws) {
        lua_pop(L, 1);
        ws = (lg_win *)lua_newuserdata(L, sizeof(lg_win));
        lua_setfield(L, -2, title);
    } else {
        lua_pop(L, 1);
    }
    lua_pop(L, 2);
    ws->x = lg_fnum(L, 3, "x", 40), ws->y = lg_fnum(L, 3, "y", 40), ws->w = lg_fnum(L, 3, "w", 300), ws->h = lg_fnum(L, 3, "h", 0);
    ws->open = lg_fbool(L, 3, "open", 1);
    int r = goome_ui_window(u->u, title, &ws->x, &ws->y, &ws->w, &ws->h, flags, &ws->open);
    lg_win_out(L, ws, 3);
    if (u->nw < 32) {
        u->wst[u->nw] = ws;
        u->wref[u->nw++] = lg_ref(L, 3);
    }
    lua_pushboolean(L, r);
    return 1;
}

static int ui_window_end(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    goome_ui_window_end(u->u);
    lg_win_pop(L, u, 1);
    return 0;
}

#define UI_VOID(name, call) \
    static int name(lua_State *L) \
    { \
        lg_ui *u = lg_uiopen(L, 1); \
        call; \
        return 0; \
    }
#define UI_BOOL(name, call) \
    static int name(lua_State *L) \
    { \
        lg_ui *u = lg_uiopen(L, 1); \
        lua_pushboolean(L, call); \
        return 1; \
    }

UI_VOID(ui_row, goome_ui_row(u->u, (int)N(2)))
UI_VOID(ui_same_line, goome_ui_same_line(u->u))
UI_VOID(ui_space, goome_ui_space(u->u, N(2)))
UI_VOID(ui_separator, goome_ui_separator(u->u))
UI_VOID(ui_width, goome_ui_width(u->u, luaL_optnumber(L, 2, 0)))
UI_VOID(ui_label, goome_ui_label(u->u, "%s", lg_tostr(L, 2)))
UI_VOID(ui_heading, goome_ui_heading(u->u, luaL_checkstring(L, 2)))
UI_VOID(ui_wrapped, goome_ui_wrapped(u->u, luaL_checkstring(L, 2)))
UI_BOOL(ui_button, goome_ui_button(u->u, luaL_checkstring(L, 2)))
UI_VOID(ui_tooltip, goome_ui_tooltip(u->u, luaL_checkstring(L, 2)))
UI_BOOL(ui_hovered, goome_ui_hovered(u->u))
UI_VOID(ui_scroll_end, goome_ui_scroll_end(u->u))
UI_VOID(ui_pop_id, goome_ui_pop_id(u->u))
UI_VOID(ui_app_end, goome_ui_app_end(u->u))
UI_BOOL(ui_menubar, goome_ui_menubar_begin(u->u))
UI_VOID(ui_menubar_end, goome_ui_menubar_end(u->u))
UI_BOOL(ui_menu, goome_ui_menu_begin(u->u, luaL_checkstring(L, 2)))
UI_VOID(ui_menu_end, goome_ui_menu_end(u->u))
UI_VOID(ui_menu_separator, goome_ui_menu_separator(u->u))
UI_BOOL(ui_context, goome_ui_context_begin(u->u, luaL_checkstring(L, 2)))
UI_VOID(ui_context_end, goome_ui_context_end(u->u))
UI_VOID(ui_popup_open, goome_ui_popup_open(u->u, luaL_checkstring(L, 2)))
UI_BOOL(ui_popup, goome_ui_popup_begin(u->u, luaL_checkstring(L, 2)))
UI_VOID(ui_popup_end, goome_ui_popup_end(u->u))
UI_VOID(ui_popup_close, goome_ui_popup_close(u->u))
UI_VOID(ui_modal_end, goome_ui_modal_end(u->u))
UI_VOID(ui_toast, goome_ui_toast(u->u, luaL_checkstring(L, 2), (int)luaL_optnumber(L, 3, 2500)))
UI_VOID(ui_statusbar, goome_ui_statusbar(u->u, luaL_checkstring(L, 2)))
UI_BOOL(ui_focused, goome_ui_focused(u->u))
UI_VOID(ui_set_focus, goome_ui_set_focus(u->u))
UI_VOID(ui_table_column, goome_ui_table_column(u->u, luaL_checkstring(L, 2), luaL_optnumber(L, 3, 0)))
UI_VOID(ui_table_row, goome_ui_table_row(u->u))
UI_VOID(ui_table_next, goome_ui_table_next(u->u))
UI_VOID(ui_table_end, goome_ui_table_end(u->u))
UI_VOID(ui_tree_end, goome_ui_tree_end(u->u))
UI_VOID(ui_split_next, goome_ui_split_next(u->u))
UI_VOID(ui_split_end, goome_ui_split_end(u->u))
UI_VOID(ui_spinner, goome_ui_spinner(u->u, luaL_optnumber(L, 2, 16)))
UI_BOOL(ui_link, goome_ui_link(u->u, luaL_checkstring(L, 2)))
UI_VOID(ui_pos, goome_ui_pos(u->u, N(2), N(3)))
UI_VOID(ui_size, goome_ui_size(u->u, luaL_optnumber(L, 2, 0), luaL_optnumber(L, 3, 0)))
UI_VOID(ui_pop, goome_ui_pop(u->u, (int)luaL_optnumber(L, 2, 1)))
UI_VOID(ui_scale, goome_ui_scale(u->u, N(2)))
UI_BOOL(ui_selectable, goome_ui_selectable(u->u, luaL_checkstring(L, 2), lg_bool(L, 3)))
UI_VOID(ui_progress, goome_ui_progress(u->u, N(2), luaL_optstring(L, 3, NULL)))
UI_BOOL(ui_scroll, goome_ui_scroll_begin(u->u, luaL_checkstring(L, 2), luaL_optnumber(L, 3, 0)))
UI_BOOL(ui_app, goome_ui_app(u->u, luaL_optstring(L, 2, NULL), (int)luaL_optnumber(L, 3, 0)))
UI_BOOL(ui_table, goome_ui_table_begin(u->u, luaL_checkstring(L, 2), (int)N(3), luaL_optnumber(L, 4, 0), (int)luaL_optnumber(L, 5, 0)))

static int ui_push_id(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    goome_ui_push_id(u->u, lg_tostr(L, 2));
    return 0;
}

static int ui_badge(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    goome_ui_badge(u->u, luaL_checkstring(L, 2), lg_optu32(L, 3, goome_ui_theme(u->u)->badge));
    return 0;
}

static int ui_image_button(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    lg_bmp *b = lg_bm(L, 3);
    lg_frame_keep(L, u, 3);
    lua_pushboolean(L, goome_ui_image_button(u->u, luaL_checkstring(L, 2), &b->b, N(4), N(5)));
    return 1;
}

static int ui_image(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    lg_bmp *b = lg_bm(L, 2);
    lg_frame_keep(L, u, 2);
    goome_ui_image(u->u, &b->b, N(3), N(4), luaL_optnumber(L, 5, 0));
    return 0;
}

static int lg_flag_widget(lua_State *L, int (*fn)(goome_ui *, const char *, int *))
{
    lg_ui *u = lg_uiopen(L, 1);
    int v = lg_bool(L, 3);
    int r = fn(u->u, luaL_checkstring(L, 2), &v);
    lua_pushboolean(L, v);
    lua_pushboolean(L, r);
    return 2;
}

static int ui_checkbox(lua_State *L)
{
    return lg_flag_widget(L, goome_ui_checkbox);
}

static int ui_toggle(lua_State *L)
{
    return lg_flag_widget(L, goome_ui_toggle);
}

static int ui_radio(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    int v = (int)luaL_optnumber(L, 3, 0);
    int r = goome_ui_radio(u->u, luaL_checkstring(L, 2), &v, (int)N(4));
    lua_pushinteger(L, v);
    lua_pushboolean(L, r);
    return 2;
}

static int ui_slider(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    double v = luaL_optnumber(L, 3, 0);
    int r = goome_ui_slider(u->u, luaL_checkstring(L, 2), &v, luaL_optnumber(L, 4, 0), luaL_optnumber(L, 5, 1), luaL_optstring(L, 6, NULL));
    lua_pushnumber(L, v);
    lua_pushboolean(L, r);
    return 2;
}

static int ui_slider_int(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    int v = (int)luaL_optnumber(L, 3, 0);
    int r = goome_ui_slider_int(u->u, luaL_checkstring(L, 2), &v, (int)luaL_optnumber(L, 4, 0), (int)luaL_optnumber(L, 5, 100));
    lua_pushinteger(L, v);
    lua_pushboolean(L, r);
    return 2;
}

static char *lg_textbuf(lua_State *L, int i, int cap, char *small, int nsmall)
{
    size_t n = 0;
    const char *s = lua_isnoneornil(L, i) ? "" : luaL_checklstring(L, i, &n);
    char *b = cap <= nsmall ? small : (char *)malloc(cap);
    if (!b) luaL_error(L, "out of memory");
    if ((int)n >= cap) n = cap - 1;
    memcpy(b, s, n);
    b[n] = 0;
    return b;
}

static int ui_input_common(lua_State *L, int ex)
{
    lg_ui *u = lg_uiopen(L, 1);
    int flags = ex ? (int)luaL_optnumber(L, 4, 0) : 0;
    const char *hint = ex ? luaL_optstring(L, 5, NULL) : NULL;
    int cap = (int)luaL_optnumber(L, ex ? 6 : 4, 256);
    if (cap < 1) cap = 1;
    char small[512];
    char *b = lg_textbuf(L, 3, cap, small, sizeof(small));
    int r = ex ? goome_ui_input_ex(u->u, luaL_checkstring(L, 2), b, cap, flags, hint) : goome_ui_input(u->u, luaL_checkstring(L, 2), b, cap);
    lua_pushstring(L, b);
    if (b != small) free(b);
    lua_pushboolean(L, r);
    return 2;
}

static int ui_input(lua_State *L)
{
    return ui_input_common(L, 0);
}

static int ui_input_ex(lua_State *L)
{
    return ui_input_common(L, 1);
}

static int ui_password(lua_State *L)
{
    lua_settop(L, 6);
    int flags = GOOME_INPUT_PASSWORD | (int)luaL_optnumber(L, 5, 0);
    lua_pushvalue(L, 4);
    lua_pushinteger(L, flags);
    lua_replace(L, 4);
    lua_replace(L, 5);
    return ui_input_common(L, 1);
}

static const char **lg_strs(lua_State *L, int i, int *n)
{
    luaL_checktype(L, i, LUA_TTABLE);
    *n = LG_LEN(L, i);
    const char **a = (const char **)malloc(sizeof(char *) * (*n > 0 ? *n : 1));
    if (!a) luaL_error(L, "out of memory");
    for (int k = 0; k < *n; k++) {
        lua_rawgeti(L, i, k + 1);
        a[k] = lua_tostring(L, -1);
        lua_pop(L, 1);
        if (!a[k]) a[k] = "";
    }
    return a;
}

static int ui_combo(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    int n, sel = (int)luaL_optnumber(L, 3, 1) - 1;
    const char **items = lg_strs(L, 4, &n);
    int r = goome_ui_combo(u->u, luaL_checkstring(L, 2), &sel, items, n);
    free((void *)items);
    lua_pushinteger(L, sel + 1);
    lua_pushboolean(L, r);
    return 2;
}

static int ui_tabs(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    int n, sel = (int)luaL_optnumber(L, 4, 1) - 1;
    const char **names = lg_strs(L, 3, &n);
    int r = goome_ui_tabs(u->u, luaL_checkstring(L, 2), names, n, &sel);
    free((void *)names);
    lua_pushinteger(L, sel + 1);
    lua_pushboolean(L, r);
    return 2;
}

static int lg_open_widget(lua_State *L, int (*fn)(goome_ui *, const char *, int *))
{
    lg_ui *u = lg_uiopen(L, 1);
    if (lua_isnoneornil(L, 3)) {
        lua_pushboolean(L, fn(u->u, luaL_checkstring(L, 2), NULL));
        return 1;
    }
    int v = lg_bool(L, 3);
    int r = fn(u->u, luaL_checkstring(L, 2), &v);
    lua_pushboolean(L, r);
    lua_pushboolean(L, v);
    return 2;
}

static int ui_collapsing(lua_State *L)
{
    return lg_open_widget(L, goome_ui_collapsing);
}

static int ui_tree(lua_State *L)
{
    return lg_open_widget(L, goome_ui_tree);
}

static int ui_modal(lua_State *L)
{
    return lg_open_widget(L, goome_ui_modal_begin);
}

static int ui_color(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    uint32_t v = lg_u32(L, 3);
    int r = goome_ui_color(u->u, luaL_checkstring(L, 2), &v);
    lua_pushnumber(L, (lua_Number)v);
    lua_pushboolean(L, r);
    return 2;
}

static int ui_menu_item(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    const char *sc = luaL_optstring(L, 3, NULL);
    if (lua_isnoneornil(L, 4)) {
        lua_pushboolean(L, goome_ui_menu_item(u->u, luaL_checkstring(L, 2), sc, NULL));
        return 1;
    }
    int v = lg_bool(L, 4);
    int r = goome_ui_menu_item(u->u, luaL_checkstring(L, 2), sc, &v);
    lua_pushboolean(L, r);
    lua_pushboolean(L, v);
    return 2;
}

static int ui_text_edit(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    const char *id = luaL_checkstring(L, 2);
    size_t n = 0;
    const char *s = lua_isnoneornil(L, 3) ? "" : luaL_checklstring(L, 3, &n);
    int cap = lua_isnoneornil(L, 6) ? (int)(n * 4 > 65536 ? n * 4 : 65536) : (int)N(6);
    if (cap < 2) cap = 2;
    lg_getref(L, u->refs);
    lua_getfield(L, -1, "edits");
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_pushvalue(L, -1);
        lua_setfield(L, -3, "edits");
    }
    lua_getfield(L, -1, id);
    char *buf = (char *)lua_touserdata(L, -1);
    int have = buf ? (int)LG_LEN(L, -1) : 0;
    if (!buf || (lua_isnoneornil(L, 6) ? (int)n * 4 > have * 3 : have != cap)) {
        lua_pop(L, 1);
        buf = (char *)lua_newuserdata(L, cap);
        buf[0] = 0;
        lua_pushvalue(L, -1);
        lua_setfield(L, -3, id);
        have = cap;
    }
    if ((int)n >= have) n = have - 1;
    if (strlen(buf) != n || memcmp(buf, s, n)) {
        memcpy(buf, s, n);
        buf[n] = 0;
    }
    int r = goome_ui_text_edit(u->u, id, buf, have, luaL_optnumber(L, 4, 0), (int)luaL_optnumber(L, 5, 0));
    lua_pushstring(L, buf);
    lua_pushboolean(L, r);
    return 2;
}

static int ui_table_sort(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    int col = (int)luaL_optnumber(L, 2, 1) - 1, desc = lg_bool(L, 3);
    int r = goome_ui_table_sort(u->u, &col, &desc);
    lua_pushboolean(L, r);
    lua_pushinteger(L, col + 1);
    lua_pushboolean(L, desc);
    return 3;
}

static int ui_list_clip(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    int first = 0, last = 0;
    goome_ui_list_clip(u->u, (int)N(2), luaL_optnumber(L, 3, 0), &first, &last);
    lua_pushinteger(L, first + 1);
    lua_pushinteger(L, last);
    return 2;
}

static int ui_drag_float(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    double v = luaL_optnumber(L, 3, 0);
    int r = goome_ui_drag_float(u->u, luaL_checkstring(L, 2), &v, luaL_optnumber(L, 4, 1), luaL_optnumber(L, 5, 0), luaL_optnumber(L, 6, 0), luaL_optstring(L, 7, NULL));
    lua_pushnumber(L, v);
    lua_pushboolean(L, r);
    return 2;
}

static int ui_drag_int(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    int v = (int)luaL_optnumber(L, 3, 0);
    int r = goome_ui_drag_int(u->u, luaL_checkstring(L, 2), &v, luaL_optnumber(L, 4, 1), (int)luaL_optnumber(L, 5, 0), (int)luaL_optnumber(L, 6, 0));
    lua_pushinteger(L, v);
    lua_pushboolean(L, r);
    return 2;
}

static int ui_number(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    double v = luaL_optnumber(L, 3, 0);
    int r = goome_ui_number(u->u, luaL_checkstring(L, 2), &v, luaL_optnumber(L, 4, 1), luaL_optstring(L, 5, NULL));
    lua_pushnumber(L, v);
    lua_pushboolean(L, r);
    return 2;
}

static int lg_plot(lua_State *L, void (*fn)(goome_ui *, const char *, const float *, int, double, double, double))
{
    lg_ui *u = lg_uiopen(L, 1);
    luaL_checktype(L, 3, LUA_TTABLE);
    int n = LG_LEN(L, 3);
    float *v = (float *)malloc(sizeof(float) * (n > 0 ? n : 1));
    if (!v) return luaL_error(L, "out of memory");
    double lo = 0, hi = 0;
    for (int k = 0; k < n; k++) {
        lua_rawgeti(L, 3, k + 1);
        v[k] = (float)lua_tonumber(L, -1);
        lua_pop(L, 1);
        if (!k || v[k] < lo) lo = v[k];
        if (!k || v[k] > hi) hi = v[k];
    }
    fn(u->u, luaL_checkstring(L, 2), v, n, luaL_optnumber(L, 4, lo), luaL_optnumber(L, 5, hi), luaL_optnumber(L, 6, 60));
    free(v);
    return 0;
}

static int ui_plot_lines(lua_State *L)
{
    return lg_plot(L, goome_ui_plot_lines);
}

static int ui_plot_bars(lua_State *L)
{
    return lg_plot(L, goome_ui_plot_bars);
}

static int ui_split(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    double frac = luaL_optnumber(L, 3, 0.5);
    int r = goome_ui_split_begin(u->u, luaL_checkstring(L, 2), lg_bool(L, 4), &frac);
    lua_pushboolean(L, r);
    lua_pushnumber(L, frac);
    return 2;
}

static int ui_drag_source(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    size_t n;
    const char *d = luaL_checklstring(L, 3, &n);
    lua_pushboolean(L, goome_ui_drag_source(u->u, luaL_checkstring(L, 2), d, (int)n));
    return 1;
}

static int ui_drop_target(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    int cap = (int)luaL_optnumber(L, 3, 4096);
    char *b = (char *)malloc(cap > 0 ? cap : 1);
    if (!b) return luaL_error(L, "out of memory");
    int n = goome_ui_drop_target(u->u, luaL_checkstring(L, 2), b, cap);
    if (n > 0) lua_pushlstring(L, b, n > cap ? cap : n);
    else lua_pushnil(L);
    free(b);
    return 1;
}

static const char *const lg_style_names[] = {
    "bg", "panel", "border", "text", "text_dim", "accent", "accent_text", "hover", "active", "input_bg", "shadow",
    "radius", "pad", "gap", "border_width", "font_size", "shadow_blur", "anim_ms",
    "focus", "select", "caret", "link", "badge", "toast", "tooltip", "danger", "knob", "dim",
    "check_size", "check_radius", "toggle_w", "toggle_h", "slider_h", "slider_track", "knob_size",
    "scroll_w", "scroll_min", "item_h", "menu_item_h", "tab_h", "win_title_h", "app_title_h", "menubar_h", "statusbar_h",
    "focus_w", "focus_gap", "sep_w", "grip", "indent", "plot_w", "spinner", "caret_w",
    "win_min_w", "win_min_h", "pop_gap", "menu_gap", "tip_pad_x", "tip_pad_y", "tip_x", "tip_y", "tip_radius",
    "shadow_x", "shadow_y", "align", "heading_size", "small_size", "ease",
    "hover_ms", "press_ms", "popup_ms", "collapse_ms", "toast_fade_ms", NULL,
};

static const char *const lg_skin_names[] = {"button", "panel", "input", "checkbox", "radio", "toggle", "slider_track", "slider_fill",
                                            "scrollbar", "tab", "titlebar", "tooltip", "menu", "popup", NULL};

static int ui_push_color(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    goome_ui_push_color(u->u, lg_named(L, 2, lg_style_names, 0), lg_u32(L, 3));
    return 0;
}

static int ui_push_num(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    goome_ui_push_num(u->u, lg_named(L, 2, lg_style_names, 0), N(3));
    return 0;
}

static int ui_push_radii(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    goome_ui_push_radii(u->u, lg_radii(L, 2));
    return 0;
}

static int ui_push_font(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    goome_font *f = lg_optfont(L, 2);
    if (f) lg_frame_keep(L, u, 2);
    goome_ui_push_font(u->u, f);
    return 0;
}

static int lg_skin_at(lua_State *L, int i, goome_skin *s)
{
    memset(s, 0, sizeof(*s));
    if (lua_isnoneornil(L, i)) return 0;
    lg_bmp *b = (lg_bmp *)lg_test(L, i, MT_BMP);
    if (b) {
        s->bm = &b->b;
        return 1;
    }
    luaL_checktype(L, i, LUA_TTABLE);
    lua_rawgeti(L, i, 1);
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_getfield(L, i, "bitmap");
    }
    b = (lg_bmp *)lg_check(L, lua_gettop(L), MT_BMP);
    if (b->closed) luaL_error(L, "this bitmap is closed");
    lua_pop(L, 1);
    s->bm = &b->b;
    double v[4];
    for (int k = 0; k < 4; k++) {
        lua_rawgeti(L, i, k + 2);
        v[k] = lua_isnumber(L, -1) ? lua_tonumber(L, -1) : (k ? v[0] : 0);
        lua_pop(L, 1);
    }
    s->l = lg_fnum(L, i, "l", v[0]);
    s->t = lg_fnum(L, i, "t", v[1]);
    s->r = lg_fnum(L, i, "r", v[2]);
    s->b = lg_fnum(L, i, "b", v[3]);
    return 1;
}

static void lg_skin_bmp_push(lua_State *L, int i)
{
    if (lg_test(L, i, MT_BMP)) {
        lua_pushvalue(L, i);
        return;
    }
    lua_rawgeti(L, i, 1);
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_getfield(L, i, "bitmap");
    }
}

static int ui_push_skin(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    int kind = lg_named(L, 2, lg_skin_names, 0);
    goome_skin s;
    if (lg_skin_at(L, 3, &s)) {
        lg_skin_bmp_push(L, 3);
        lg_frame_keep(L, u, lua_gettop(L));
        lua_pop(L, 1);
        goome_ui_push_skin(u->u, kind, &s);
    } else {
        goome_ui_push_skin(u->u, kind, NULL);
    }
    return 0;
}

static int ui_push_icon(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    lg_bmp *b = lg_optbm(L, 3);
    if (b) lg_frame_keep(L, u, 3);
    goome_ui_push_icon(u->u, (int)N(2), b ? &b->b : NULL);
    return 0;
}

static lg_theme *lg_th(lua_State *L, int i);

static int ui_push_theme(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    lg_theme *t = lg_th(L, 2);
    lg_frame_keep(L, u, 2);
    goome_ui_push_theme(u->u, t->t);
    return 0;
}

static int ui_custom(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    goome_ui_item it;
    memset(&it, 0, sizeof(it));
    int r = goome_ui_custom(u->u, luaL_checkstring(L, 2), luaL_optnumber(L, 3, 0), luaL_optnumber(L, 4, 0), (int)luaL_optnumber(L, 5, 0), &it);
    lua_pushboolean(L, r);
    lua_createtable(L, 0, 19);
#define IT_N(f) lua_pushnumber(L, it.f), lua_setfield(L, -2, #f)
#define IT_B(f) lua_pushboolean(L, it.f), lua_setfield(L, -2, #f)
    IT_N(x), IT_N(y), IT_N(w), IT_N(h);
    IT_B(hovered), IT_B(pressed), IT_B(held), IT_B(released), IT_B(clicked), IT_B(double_clicked), IT_B(right_clicked), IT_B(focused);
    IT_N(mx), IT_N(my), IT_N(dx), IT_N(dy), IT_N(drag_x), IT_N(drag_y);
    lua_pushinteger(L, it.key);
    lua_setfield(L, -2, "key");
    return 2;
}

static int ui_anim(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    lua_pushnumber(L, goome_ui_anim(u->u, lg_tostr(L, 2), N(3), luaL_optnumber(L, 4, 200), (int)luaL_optnumber(L, 5, GOOME_EASE_OUT)));
    return 1;
}

static int ui_anim_color(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    uint32_t c = goome_ui_anim_color(u->u, lg_tostr(L, 2), lg_u32(L, 3), luaL_optnumber(L, 4, 200), (int)luaL_optnumber(L, 5, GOOME_EASE_OUT));
    lua_pushnumber(L, (lua_Number)c);
    return 1;
}

static int ui_a11y(lua_State *L)
{
    goome_ui_a11y(lg_uiopen(L, 1)->u, lua_isnone(L, 2) ? 1 : lg_bool(L, 2));
    return 0;
}

static int ui_a11y_role(lua_State *L)
{
    goome_ui_a11y_role(lg_uiopen(L, 1)->u, (int)N(2), luaL_optstring(L, 3, NULL));
    return 0;
}

static int ui_a11y_value(lua_State *L)
{
    goome_ui_a11y_value(lg_uiopen(L, 1)->u, luaL_optstring(L, 2, NULL));
    return 0;
}

static void lg_cstr_field(lua_State *L, const char *s, size_t cap, const char *k)
{
    const char *e = (const char *)memchr(s, 0, cap);
    lua_pushlstring(L, s, e ? (size_t)(e - s) : cap);
    lua_setfield(L, -2, k);
}

static int ui_a11y_tree(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    int n = goome_a11y_tree(u->u, NULL, 0);
    goome_a11y_node *ns = n > 0 ? (goome_a11y_node *)malloc(sizeof(goome_a11y_node) * (size_t)n) : NULL;
    if (n > 0 && !ns) return luaL_error(L, "out of memory");
    if (ns) {
        int m = goome_a11y_tree(u->u, ns, n);
        if (m < n) n = m;
    }
    lua_createtable(L, n > 0 ? n : 0, 0);
    static const char *const states[] = {"focused", "checked", "disabled", "expanded", "selected"};
    for (int i = 0; i < n; i++) {
        const goome_a11y_node *a = &ns[i];
        lua_createtable(L, 0, 20);
        lua_pushinteger(L, a->role);
        lua_setfield(L, -2, "role");
        if (a->parent >= 0 && a->parent < n) {
            lua_pushinteger(L, a->parent + 1);
            lua_setfield(L, -2, "parent");
        }
        lua_pushinteger(L, a->states);
        lua_setfield(L, -2, "states");
        for (int k = 0; k < 5; k++) {
            lua_pushboolean(L, (a->states >> k) & 1);
            lua_setfield(L, -2, states[k]);
        }
        lua_pushnumber(L, a->x);
        lua_setfield(L, -2, "x");
        lua_pushnumber(L, a->y);
        lua_setfield(L, -2, "y");
        lua_pushnumber(L, a->w);
        lua_setfield(L, -2, "w");
        lua_pushnumber(L, a->h);
        lua_setfield(L, -2, "h");
        lg_cstr_field(L, a->label, sizeof(a->label), "label");
        lg_cstr_field(L, a->value, sizeof(a->value), "value");
        lua_pushnumber(L, (lua_Number)a->id);
        lua_setfield(L, -2, "id");
        lua_pushnumber(L, a->num);
        lua_setfield(L, -2, "num");
        lua_pushnumber(L, a->min);
        lua_setfield(L, -2, "min");
        lua_pushnumber(L, a->max);
        lua_setfield(L, -2, "max");
        lua_pushinteger(L, a->caret);
        lua_setfield(L, -2, "caret");
        lua_rawseti(L, -2, i + 1);
    }
    free(ns);
    return 1;
}

static int ui_canvas(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    goome_canvas *c = goome_ui_canvas(u->u);
    if (!c) {
        lua_pushnil(L);
        return 1;
    }
    return lg_push_canvas(L, c, u->live);
}

static int ui_store(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    int n = (int)N(3);
    double *p = goome_ui_store(u->u, luaL_checkstring(L, 2), n);
    if (!p) {
        lua_pushnil(L);
        return 1;
    }
    lg_store *s = (lg_store *)lua_newuserdata(L, sizeof(lg_store));
    s->p = p, s->n = n;
    s->uiref = lg_ref(L, 1);
    lg_newmt(L, MT_STORE);
    return 1;
}

static lg_store *lg_st(lua_State *L)
{
    lg_store *s = (lg_store *)lg_check(L, 1, MT_STORE);
    lg_getref(L, s->uiref);
    lg_ui *u = (lg_ui *)lua_touserdata(L, -1);
    lua_pop(L, 1);
    if (!u || !u->u) luaL_error(L, "the ui this store came from is closed");
    return s;
}

static int st_index(lua_State *L)
{
    lg_store *s = lg_st(L);
    int i = (int)luaL_checknumber(L, 2);
    if (i < 1 || i > s->n) lua_pushnil(L);
    else lua_pushnumber(L, s->p[i - 1]);
    return 1;
}

static int st_newindex(lua_State *L)
{
    lg_store *s = lg_st(L);
    int i = (int)luaL_checknumber(L, 2);
    if (i < 1 || i > s->n) return luaL_error(L, "store index %d is outside 1..%d", i, s->n);
    s->p[i - 1] = N(3);
    return 0;
}

static int st_len(lua_State *L)
{
    lua_pushinteger(L, lg_st(L)->n);
    return 1;
}

static int st_gc(lua_State *L)
{
    lg_store *s = (lg_store *)lua_touserdata(L, 1);
    lg_unref(L, &s->uiref);
    return 0;
}

#define TF(f, k) {#f, (int)offsetof(goome_theme, f), k}
static const lg_field th_fields[] = {
    TF(bg, K_U32), TF(panel, K_U32), TF(border, K_U32), TF(text, K_U32), TF(text_dim, K_U32), TF(accent, K_U32), TF(accent_text, K_U32),
    TF(hover, K_U32), TF(active, K_U32), TF(input_bg, K_U32), TF(shadow, K_U32),
    TF(radius, K_DBL), TF(pad, K_DBL), TF(gap, K_DBL), TF(border_width, K_DBL), TF(font_size, K_DBL), TF(shadow_blur, K_DBL), TF(anim_ms, K_DBL),
    TF(font, K_FONT), TF(skin_button, K_SKIN), TF(skin_panel, K_SKIN), TF(skin_input, K_SKIN), TF(icon_tint, K_U32),
    TF(skin_checkbox, K_SKIN), TF(skin_radio, K_SKIN), TF(skin_toggle, K_SKIN), TF(skin_slider, K_SKIN), TF(skin_slider_fill, K_SKIN),
    TF(skin_scrollbar, K_SKIN), TF(skin_tab, K_SKIN), TF(skin_titlebar, K_SKIN), TF(skin_tooltip, K_SKIN), TF(skin_menu, K_SKIN), TF(skin_popup, K_SKIN),
    TF(focus, K_U32), TF(select, K_U32), TF(caret, K_U32), TF(link, K_U32), TF(badge, K_U32), TF(toast, K_U32), TF(tooltip, K_U32),
    TF(danger, K_U32), TF(knob, K_U32), TF(dim, K_U32),
    TF(check_size, K_DBL), TF(check_radius, K_DBL), TF(toggle_w, K_DBL), TF(toggle_h, K_DBL), TF(slider_h, K_DBL), TF(slider_track, K_DBL), TF(knob_size, K_DBL),
    TF(scroll_w, K_DBL), TF(scroll_min, K_DBL), TF(item_h, K_DBL), TF(menu_item_h, K_DBL), TF(tab_h, K_DBL), TF(win_title_h, K_DBL), TF(app_title_h, K_DBL),
    TF(menubar_h, K_DBL), TF(statusbar_h, K_DBL), TF(focus_w, K_DBL), TF(focus_gap, K_DBL), TF(sep_w, K_DBL), TF(grip, K_DBL), TF(indent, K_DBL),
    TF(plot_w, K_DBL), TF(spinner, K_DBL), TF(caret_w, K_DBL), TF(win_min_w, K_DBL), TF(win_min_h, K_DBL), TF(pop_gap, K_DBL), TF(menu_gap, K_DBL),
    TF(tip_pad_x, K_DBL), TF(tip_pad_y, K_DBL), TF(tip_x, K_DBL), TF(tip_y, K_DBL), TF(tip_radius, K_DBL), TF(shadow_x, K_DBL), TF(shadow_y, K_DBL),
    TF(align, K_DBL), TF(heading_size, K_DBL), TF(small_size, K_DBL), TF(ease, K_DBL), TF(hover_ms, K_DBL), TF(press_ms, K_DBL), TF(popup_ms, K_DBL),
    TF(collapse_ms, K_DBL), TF(toast_fade_ms, K_DBL), TF(font_heading, K_FONT), TF(font_mono, K_FONT), TF(font_small, K_FONT),
    {NULL, 0, 0},
};

static int lg_push_theme(lua_State *L, goome_theme *t, int uii)
{
    lg_theme *th = (lg_theme *)lua_newuserdata(L, sizeof(lg_theme));
    memset(th, 0, sizeof(*th));
    th->uiref = LUA_NOREF;
    if (t) {
        th->t = t;
        th->uiref = lg_ref(L, uii);
        lg_ui *u = (lg_ui *)lua_touserdata(L, uii);
        lg_getref(L, u->refs);
        th->refs = luaL_ref(L, LUA_REGISTRYINDEX);
    } else {
        goome_ui_theme_dark(&th->own);
        th->t = &th->own;
        lua_newtable(L);
        th->refs = luaL_ref(L, LUA_REGISTRYINDEX);
    }
    lg_newmt(L, MT_THEME);
    return 1;
}

static int ui_theme(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    return lg_push_theme(L, goome_ui_theme(u->u), 1);
}

static int l_theme_new(lua_State *L)
{
    return lg_push_theme(L, NULL, 0);
}

static lg_theme *lg_th(lua_State *L, int i)
{
    lg_theme *t = (lg_theme *)lg_check(L, i, MT_THEME);
    if (t->uiref != LUA_NOREF) {
        lg_getref(L, t->uiref);
        lg_ui *u = (lg_ui *)lua_touserdata(L, -1);
        lua_pop(L, 1);
        if (!u || !u->u) luaL_error(L, "the ui this theme came from is closed");
        lg_getref(L, u->refs);
        lua_rawseti(L, LUA_REGISTRYINDEX, t->refs);
    }
    return t;
}

static int th_gc(lua_State *L)
{
    lg_theme *t = (lg_theme *)lua_touserdata(L, 1);
    if (t->uiref == LUA_NOREF && t->refs != LUA_NOREF) lg_release_all(L, t->refs);
    lg_unref(L, &t->uiref);
    lg_unref(L, &t->refs);
    return 0;
}

static int th_index(lua_State *L)
{
    if (lg_methods_first(L)) return 1;
    lg_theme *t = lg_th(L, 1);
    const char *k = lua_tostring(L, 2);
    const lg_field *f = k ? lg_find(th_fields, k) : NULL;
    if (!f) return 0;
    if (f->kind == K_FONT || f->kind == K_SKIN) {
        char *p = (char *)t->t + f->off;
        lg_getref(L, t->refs);
        lua_getfield(L, -1, k);
        if (f->kind == K_FONT) {
            goome_font *gf = *(goome_font **)p;
            lg_font *lf = (lg_font *)lg_test(L, -1, MT_FONT);
            if (lf && lf->f == gf) return 1;
            lua_pop(L, 1);
            if (gf) lua_pushlightuserdata(L, gf);
            else lua_pushnil(L);
            return 1;
        }
        goome_skin *s = (goome_skin *)p;
        if (!s->bm) {
            lua_pushnil(L);
            return 1;
        }
        lua_createtable(L, 4, 1);
        lua_pushvalue(L, -2);
        lua_rawseti(L, -2, 1);
        lua_pushnumber(L, s->l);
        lua_rawseti(L, -2, 2);
        lua_pushnumber(L, s->t);
        lua_rawseti(L, -2, 3);
        lua_pushnumber(L, s->r);
        lua_rawseti(L, -2, 4);
        lua_pushnumber(L, s->b);
        lua_rawseti(L, -2, 5);
        return 1;
    }
    return lg_get_plain(L, t->t, f);
}

static int th_newindex(lua_State *L)
{
    lg_theme *t = lg_th(L, 1);
    const char *k = luaL_checkstring(L, 2);
    const lg_field *f = lg_find(th_fields, k);
    if (!f) return luaL_error(L, "theme has no field %s", k);
    char *p = (char *)t->t + f->off;
    if (f->kind == K_FONT) {
        if (lua_islightuserdata(L, 3)) {
            *(goome_font **)p = (goome_font *)lua_touserdata(L, 3);
            return 0;
        }
        goome_font *gf = lg_optfont(L, 3);
        lg_retain(L, t->refs, k, 3);
        *(goome_font **)p = gf;
        return 0;
    }
    if (f->kind == K_SKIN) {
        goome_skin s;
        if (lg_skin_at(L, 3, &s)) {
            lg_skin_bmp_push(L, 3);
            lg_retain(L, t->refs, k, lua_gettop(L));
            lua_pop(L, 1);
        } else {
            lg_retain(L, t->refs, k, 0);
        }
        *(goome_skin *)p = s;
        return 0;
    }
    lg_set_plain(L, t->t, f, 3);
    return 0;
}

static int th_dark(lua_State *L)
{
    goome_ui_theme_dark(lg_th(L, 1)->t);
    return 0;
}

static int th_light(lua_State *L)
{
    goome_ui_theme_light(lg_th(L, 1)->t);
    return 0;
}

static int th_make(lua_State *L)
{
    goome_ui_theme_make(lg_th(L, 1)->t, lg_u32(L, 2), lua_isnone(L, 3) ? 1 : lg_bool(L, 3), luaL_optnumber(L, 4, 10));
    return 0;
}

static const char *const lg_presets[] = {"dark", "light", "midnight", "paper", "mint", "high_contrast", "rose", NULL};

static int th_preset(lua_State *L)
{
    lg_theme *t = lg_th(L, 1);
    int rc = goome_ui_theme_preset(t->t, lg_named(L, 2, lg_presets, 0));
    return lg_res(L, NULL, rc);
}

static int th_icon(lua_State *L)
{
    lg_theme *t = lg_th(L, 1);
    int i = (int)N(2);
    if (i < 0 || i >= GOOME_ICON_COUNT) return luaL_error(L, "no icon %d", i);
    char slot[16];
    snprintf(slot, sizeof(slot), "icon%d", i);
    if (lua_gettop(L) < 3) {
        lg_getref(L, t->refs);
        lua_getfield(L, -1, slot);
        lg_bmp *b = (lg_bmp *)lg_test(L, -1, MT_BMP);
        if (b && &b->b == t->t->icon[i]) return 1;
        lua_pushnil(L);
        return 1;
    }
    lg_bmp *b = lg_optbm(L, 3);
    lg_retain(L, t->refs, slot, b ? 3 : 0);
    t->t->icon[i] = b ? &b->b : NULL;
    return 0;
}

static int th_copy(lua_State *L)
{
    lg_theme *t = lg_th(L, 1);
    lg_push_theme(L, NULL, 0);
    lg_theme *n = (lg_theme *)lua_touserdata(L, -1);
    n->own = *t->t;
    lg_getref(L, t->refs);
    lua_pushnil(L);
    while (lua_next(L, -2)) {
        if (lua_type(L, -2) == LUA_TSTRING && (lg_test(L, -1, MT_BMP) || lg_test(L, -1, MT_FONT)))
            lg_retain(L, n->refs, lua_tostring(L, -2), lua_gettop(L));
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
    return 1;
}

static int th_fields_list(lua_State *L)
{
    lua_newtable(L);
    int k = 1;
    for (const lg_field *f = th_fields; f->name; f++) {
        lua_pushstring(L, f->name);
        lua_rawseti(L, -2, k++);
    }
    return 1;
}

#define GF(f, k) {#f, (int)offsetof(goome_ui_config, f), k}
static const lg_field cfg_fields[] = {
    GF(tip_delay_ms, K_INT), GF(dbl_click_ms, K_INT), GF(dbl_click_px, K_INT), GF(drag_px, K_INT), GF(repeat_delay_ms, K_INT),
    GF(repeat_ms, K_INT), GF(blink_ms, K_INT), GF(menu_delay_ms, K_INT), GF(toast_ms, K_INT), GF(scroll_lines, K_DBL),
    GF(raise_on_click, K_BOOL), GF(esc_closes, K_BOOL), GF(tab_nav, K_BOOL), GF(focus_on_mouse, K_BOOL), {NULL, 0, 0},
};

static lg_ui *lg_cfg_ui(lua_State *L)
{
    lg_cfg *c = (lg_cfg *)lg_check(L, 1, MT_CFG);
    lg_getref(L, c->uiref);
    lg_ui *u = (lg_ui *)lua_touserdata(L, -1);
    lua_pop(L, 1);
    if (!u || !u->u) luaL_error(L, "the ui this config came from is closed");
    u->L = L;
    return u;
}

static int ui_cfg(lua_State *L)
{
    lg_uiopen(L, 1);
    lg_cfg *c = (lg_cfg *)lua_newuserdata(L, sizeof(lg_cfg));
    c->uiref = lg_ref(L, 1);
    lg_newmt(L, MT_CFG);
    return 1;
}

static int cfg_gc(lua_State *L)
{
    lg_unref(L, &((lg_cfg *)lua_touserdata(L, 1))->uiref);
    return 0;
}

static double lg_ease(double t, void *user)
{
    lg_ui *u = (lg_ui *)user;
    lua_State *L = u->L;
    if (!L || u->ease_ref == LUA_NOREF) return t;
    lg_getref(L, u->ease_ref);
    lua_pushnumber(L, t);
    if (lua_pcall(L, 1, 1, 0)) {
        lua_pop(L, 1);
        return t;
    }
    double v = lua_isnumber(L, -1) ? lua_tonumber(L, -1) : t;
    lua_pop(L, 1);
    return v;
}

static int cfg_index(lua_State *L)
{
    if (lg_methods_first(L)) return 1;
    lg_ui *u = lg_cfg_ui(L);
    goome_ui_config *c = goome_ui_cfg(u->u);
    const char *k = lua_tostring(L, 2);
    if (!k) return 0;
    if (!strcmp(k, "mask")) {
        if (c->mask) lua_pushstring(L, c->mask);
        else lua_pushnil(L);
        return 1;
    }
    if (!strcmp(k, "ease")) {
        if (c->ease == lg_ease) lg_getref(L, u->ease_ref);
        else if (c->ease) lua_pushlightuserdata(L, (void *)c);
        else lua_pushnil(L);
        return 1;
    }
    const lg_field *f = lg_find(cfg_fields, k);
    return f ? lg_get_plain(L, c, f) : 0;
}

static int cfg_newindex(lua_State *L)
{
    lg_ui *u = lg_cfg_ui(L);
    goome_ui_config *c = goome_ui_cfg(u->u);
    const char *k = luaL_checkstring(L, 2);
    if (!strcmp(k, "mask")) {
        const char *s = luaL_optstring(L, 3, NULL);
        char *m = NULL;
        if (s) {
            m = (char *)malloc(strlen(s) + 1);
            if (!m) return luaL_error(L, "out of memory");
            strcpy(m, s);
        }
        c->mask = m;
        free(u->mask);
        u->mask = m;
        return 0;
    }
    if (!strcmp(k, "ease")) {
        lg_unref(L, &u->ease_ref);
        if (lua_isnoneornil(L, 3)) {
            c->ease = NULL, c->ease_user = NULL;
        } else {
            luaL_checktype(L, 3, LUA_TFUNCTION);
            u->ease_ref = lg_ref(L, 3);
            c->ease = lg_ease, c->ease_user = u;
        }
        return 0;
    }
    const lg_field *f = lg_find(cfg_fields, k);
    if (!f) return luaL_error(L, "config has no field %s", k);
    lg_set_plain(L, c, f, 3);
    return 0;
}

static int cfg_cursor(lua_State *L)
{
    lg_ui *u = lg_cfg_ui(L);
    goome_ui_config *c = goome_ui_cfg(u->u);
    int i = (int)N(2);
    if (i < 0 || i >= GOOME_CUR_COUNT) return luaL_error(L, "no cursor slot %d", i);
    if (!lua_isnoneornil(L, 3)) c->cursor[i] = (int)N(3);
    lua_pushinteger(L, c->cursor[i]);
    return 1;
}

static int cfg_keys(lua_State *L)
{
    lg_ui *u = lg_cfg_ui(L);
    goome_ui_config *c = goome_ui_cfg(u->u);
    int a = (int)N(2);
    if (a < 0 || a >= GOOME_ACT_COUNT) return luaL_error(L, "no action %d", a);
    lua_newtable(L);
    int n = 0;
    for (int k = 0; k < 4; k++) {
        if (!c->keys[a][k].key) continue;
        lua_createtable(L, 2, 0);
        lua_pushinteger(L, c->keys[a][k].key);
        lua_rawseti(L, -2, 1);
        lua_pushinteger(L, c->keys[a][k].mods);
        lua_rawseti(L, -2, 2);
        lua_rawseti(L, -2, ++n);
    }
    return 1;
}

static int cfg_reset(lua_State *L)
{
    lg_ui *u = lg_cfg_ui(L);
    goome_ui_config_default(goome_ui_cfg(u->u));
    lg_unref(L, &u->ease_ref);
    free(u->mask);
    u->mask = NULL;
    return 0;
}

static int ui_bind(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    return lg_res(L, NULL, goome_ui_bind(u->u, (int)N(2), luaL_checkstring(L, 3)));
}

static int ui_theme_make(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    goome_ui_theme_make(goome_ui_theme(u->u), lg_u32(L, 2), lua_isnone(L, 3) ? 1 : lg_bool(L, 3), luaL_optnumber(L, 4, 10));
    return 0;
}

static int ui_theme_preset(lua_State *L)
{
    lg_ui *u = lg_uiopen(L, 1);
    return lg_res(L, NULL, goome_ui_theme_preset(goome_ui_theme(u->u), lg_named(L, 2, lg_presets, 0)));
}

static char lg_layout_buf[16384];
static int lg_layout_len;

static void lg_layout_add(const char *fmt, const char *a, const char *b, int x, int y, int two)
{
    if (lg_layout_len >= (int)sizeof(lg_layout_buf) - 256) return;
    if (two) lg_layout_len += snprintf(lg_layout_buf + lg_layout_len, sizeof(lg_layout_buf) - lg_layout_len, fmt, a, b, x, y);
    else lg_layout_len += snprintf(lg_layout_buf + lg_layout_len, sizeof(lg_layout_buf) - lg_layout_len, fmt, a, x);
}

static int l_layout(lua_State *L)
{
    lg_layout_len = 0;
#define S(t) lg_layout_add("%s %d\n", #t, NULL, (int)sizeof(t), 0, 0)
#define F(t, f) lg_layout_add("%s.%s %d %d\n", #t, #f, (int)offsetof(t, f), (int)sizeof(((t *)0)->f), 1)
#include "layout.h"
#undef S
#undef F
    lua_pushlstring(L, lg_layout_buf, lg_layout_len);
    return 1;
}

typedef struct {
    const char *name;
    int value;
} lg_const;

static const lg_const lg_consts[] = {
#include "consts.h"
    {NULL, 0},
};

static const char lg_app_lua[] =
    "local goome = ...\n"
    "local App = {}\n"
    "App.__index = App\n"
    "function goome.app(title, width, height, opts)\n"
    "  if type(title) == 'table' then opts, title = title, title.title end\n"
    "  opts = opts or {}\n"
    "  return setmetatable({title = title or 'goome', width = width or opts.width or 960, height = height or opts.height or 640,\n"
    "    flags = opts.flags or 0, fps = opts.fps or 60, idle_ms = opts.idle_ms or 500, light = opts.light, animate = false,\n"
    "    running = false, frames = 0, dirty = 0, handlers = {}}, App)\n"
    "end\n"
    "function App:frame(fn) self.draw = fn return fn end\n"
    "function App:event(fn) self.handlers[#self.handlers + 1] = fn return fn end\n"
    "function App:on_close(fn) self.closing = fn return fn end\n"
    "function App:on_start(fn) self.starting = fn return fn end\n"
    "function App:redraw() if self.dirty < 1 then self.dirty = 1 end end\n"
    "function App:quit() self.running = false end\n"
    "function App:start()\n"
    "  local g, err, code = goome.open_app(self.title, self.width, self.height)\n"
    "  if not g then return nil, err, code end\n"
    "  self.g, self.ui = g, g:ui()\n"
    "  if self.light then self.ui:theme():light() end\n"
    "  self.every = g:backend_name():match('^test') ~= nil\n"
    "  self.pace = goome.pacer(self.fps)\n"
    "  self.dirty, self.running = 2, true\n"
    "  if self.starting then self.starting(self) end\n"
    "  return self\n"
    "end\n"
    "function App:handle(ev)\n"
    "  for _, h in ipairs(self.handlers) do if h(ev) then return end end\n"
    "  self.ui:feed(ev)\n"
    "  if ev.type == goome.QUIT then self.running = false\n"
    "  elseif ev.type == goome.CLOSE and (not self.closing or self.closing(self) ~= false) then self.running = false end\n"
    "end\n"
    "function App:paint()\n"
    "  local ui = self.ui\n"
    "  if not ui:begin(0) then return end\n"
    "  ui:app(self.title, self.flags)\n"
    "  local ok, err = true, nil\n"
    "  if self.draw then ok, err = pcall(self.draw, ui, self) end\n"
    "  ui:app_end()\n"
    "  ui:finish()\n"
    "  self.frames = self.frames + 1\n"
    "  if not ok then error(err, 0) end\n"
    "end\n"
    "function App:step(wait)\n"
    "  local ui = self.ui\n"
    "  local busy = self.every or self.animate or self.dirty > 0 or ui:animating()\n"
    "  if self.dirty > 0 then self.dirty = self.dirty - 1 end\n"
    "  local timeout = 0\n"
    "  if wait ~= false then timeout = busy and self.pace:wait() or self.idle_ms end\n"
    "  for ev in self.g:events(timeout) do\n"
    "    self:handle(ev)\n"
    "    if self.dirty < 1 then self.dirty = 1 end\n"
    "    if not self.running then return false end\n"
    "  end\n"
    "  if self.running and (busy or self.dirty > 0) then self:paint() end\n"
    "  return self.running\n"
    "end\n"
    "function App:stop()\n"
    "  self.running = false\n"
    "  if self.ui then self.ui:close() end\n"
    "  if self.g then self.g:close() end\n"
    "  self.g, self.ui = nil, nil\n"
    "end\n"
    "function App:run(draw)\n"
    "  if draw then self.draw = draw end\n"
    "  local ok, err, code = self:start()\n"
    "  if not ok then return nil, err, code end\n"
    "  local fine, msg = pcall(function() while self:step() do end end)\n"
    "  self:stop()\n"
    "  if not fine then error(msg, 0) end\n"
    "  return true\n"
    "end\n";

static void lg_class(lua_State *L, const char *mt, const luaL_Reg *methods, lua_CFunction index, lua_CFunction newindex, lua_CFunction gc, lua_CFunction len)
{
    luaL_newmetatable(L, mt);
    lua_newtable(L);
    lg_setfuncs(L, methods);
    if (index) {
        lua_pushcclosure(L, index, 1);
    }
    lua_setfield(L, -2, "__index");
    if (newindex) {
        lua_pushcfunction(L, newindex);
        lua_setfield(L, -2, "__newindex");
    }
    if (gc) {
        lua_pushcfunction(L, gc);
        lua_setfield(L, -2, "__gc");
    }
    if (len) {
        lua_pushcfunction(L, len);
        lua_setfield(L, -2, "__len");
    }
    lua_pushstring(L, mt);
    lua_setfield(L, -2, "__name");
    lua_pop(L, 1);
}

static void lg_closer(lua_State *L, const char *mt, lua_CFunction fn)
{
    luaL_getmetatable(L, mt);
    lua_pushcfunction(L, fn);
    lua_setfield(L, -2, "__close");
    lua_pop(L, 1);
}

static const luaL_Reg g_methods[] = {
    {"close", g_close}, {"closed", g_closed}, {"error", g_error}, {"backend_name", g_backend_name}, {"caps", g_caps}, {"can", g_can},
    {"monitors", g_monitors}, {"capture", g_capture}, {"capture_wait", g_capture_wait}, {"alpha_at", g_alpha_at},
    {"begin", g_begin}, {"finish", g_end}, {"poll", g_poll}, {"events", g_events}, {"pointer", g_pointer},
    {"keyboard", g_keyboard}, {"grab", g_grab}, {"grabbed", g_grabbed}, {"hotkey", g_hotkey}, {"control_path", g_control_path},
    {"mode", g_mode}, {"window_title", g_window_title}, {"window_size", g_window_size}, {"window_pos", g_window_pos},
    {"window_state", g_window_state}, {"window_drag", g_window_drag}, {"window_show", g_window_show}, {"cursor", g_cursor},
    {"clipboard", g_clipboard}, {"drop_path", g_drop_path}, {"event_text", g_event_text},
    {"preedit_cursor", g_preedit_cursor}, {"text_input", g_text_input}, {"push_ime", g_push_ime}, {"push_preedit", g_push_preedit}, {"push", g_push}, {"push_text", g_push_text}, {"push_click", g_push_click},
    {"resize", g_resize}, {"last_frame", g_frame}, {"hit", g_hit}, {"frame_dirty", g_frame_dirty}, {"frame_copy", g_frame_copy},
    {"ui", g_ui}, {NULL, NULL},
};

static const luaL_Reg cv_methods[] = {
    {"valid", cv_valid}, {"clear", cv_clear}, {"rect", cv_rect}, {"round_rect", cv_round_rect}, {"frame", cv_frame},
    {"line", cv_line}, {"triangle", cv_triangle}, {"image", cv_image}, {"erase", cv_erase}, {"text", cv_text},
    {"text_width", cv_text_width}, {"blit", cv_blit}, {"clip_push", cv_clip_push}, {"clip_pop", cv_clip_pop},
    {"rrect", cv_rrect}, {"rrect_line", cv_rrect_line}, {"rrect_grad", cv_rrect_grad}, {"shadow", cv_shadow},
    {"circle", cv_circle}, {"ring", cv_ring}, {"arc", cv_arc}, {"poly", cv_poly}, {"bitmap", cv_bitmap},
    {"bitmap_part", cv_bitmap_part}, {"bitmap_nine", cv_bitmap_nine}, {"font_text", cv_font_text}, {"damage", cv_damage},
    {"hit", cv_hit}, {"pixels", lg_pixels}, {"pixel", lg_pixel}, {"set_pixel", lg_set_pixel}, {"hash", lg_hash},
    {"ptr", lg_ptr}, {"bytes", lg_bytes}, {"save_ppm", lg_save_ppm_obj}, {NULL, NULL},
};

static const luaL_Reg im_methods[] = {
    {"pixels", lg_pixels}, {"pixel", lg_pixel}, {"hash", lg_hash}, {"ptr", lg_ptr}, {"bytes", lg_bytes},
    {"copy", im_copy}, {"save_ppm", lg_save_ppm_obj}, {NULL, NULL},
};

static const luaL_Reg pix_methods[] = {
    {"get", lg_pixel}, {"set", lg_set_pixel}, {"hash", lg_hash}, {"ptr", lg_ptr}, {"bytes", lg_bytes}, {"fill", pix_fill},
    {"save_ppm", lg_save_ppm_obj}, {NULL, NULL},
};

static const luaL_Reg bmp_methods[] = {
    {"close", bmp_close}, {"pixels", lg_pixels}, {"pixel", lg_pixel}, {"set_pixel", lg_set_pixel}, {"hash", lg_hash},
    {"ptr", lg_ptr}, {"bytes", lg_bytes}, {"save_ppm", lg_save_ppm_obj}, {NULL, NULL},
};

static const luaL_Reg font_methods[] = {
    {"close", font_close}, {"measure", font_measure}, {"width", font_width}, {"line_height", font_line_height},
    {"fallback", font_fallback}, {NULL, NULL},
};

static const luaL_Reg ui_methods[] = {
    {"close", ui_close}, {"closed", ui_closed}, {"feed", ui_feed}, {"begin", ui_begin}, {"finish", ui_end}, {"hit", ui_hit},
    {"animating", ui_animating}, {"wants", ui_wants}, {"wants_mouse", ui_wants_mouse}, {"wants_keyboard", ui_wants_keyboard},
    {"auto_grab", ui_auto_grab}, {"window", ui_window}, {"window_end", ui_window_end}, {"row", ui_row}, {"same_line", ui_same_line},
    {"space", ui_space}, {"separator", ui_separator}, {"width", ui_width}, {"label", ui_label}, {"heading", ui_heading},
    {"wrapped", ui_wrapped}, {"button", ui_button}, {"image_button", ui_image_button}, {"image", ui_image},
    {"checkbox", ui_checkbox}, {"toggle", ui_toggle}, {"radio", ui_radio}, {"slider", ui_slider}, {"slider_int", ui_slider_int},
    {"input", ui_input}, {"input_ex", ui_input_ex}, {"password", ui_password}, {"combo", ui_combo}, {"selectable", ui_selectable},
    {"tabs", ui_tabs}, {"collapsing", ui_collapsing}, {"progress", ui_progress}, {"color", ui_color}, {"tooltip", ui_tooltip},
    {"hovered", ui_hovered}, {"scroll", ui_scroll}, {"scroll_end", ui_scroll_end}, {"push_id", ui_push_id}, {"pop_id", ui_pop_id},
    {"app", ui_app}, {"app_end", ui_app_end}, {"menubar", ui_menubar}, {"menubar_end", ui_menubar_end}, {"menu", ui_menu},
    {"menu_end", ui_menu_end}, {"menu_item", ui_menu_item}, {"menu_separator", ui_menu_separator}, {"context", ui_context},
    {"context_end", ui_context_end}, {"popup_open", ui_popup_open}, {"popup", ui_popup}, {"popup_end", ui_popup_end},
    {"popup_close", ui_popup_close}, {"modal", ui_modal}, {"modal_end", ui_modal_end}, {"toast", ui_toast},
    {"statusbar", ui_statusbar}, {"focused", ui_focused}, {"set_focus", ui_set_focus}, {"text_edit", ui_text_edit},
    {"table", ui_table}, {"table_column", ui_table_column}, {"table_sort", ui_table_sort}, {"table_row", ui_table_row},
    {"table_next", ui_table_next}, {"table_end", ui_table_end}, {"tree", ui_tree}, {"tree_end", ui_tree_end},
    {"list_clip", ui_list_clip}, {"drag_float", ui_drag_float}, {"drag_int", ui_drag_int}, {"number", ui_number},
    {"plot_lines", ui_plot_lines}, {"plot_bars", ui_plot_bars}, {"split", ui_split}, {"split_next", ui_split_next},
    {"split_end", ui_split_end}, {"drag_source", ui_drag_source}, {"drop_target", ui_drop_target}, {"spinner", ui_spinner},
    {"link", ui_link}, {"badge", ui_badge}, {"pos", ui_pos}, {"size", ui_size}, {"push_color", ui_push_color},
    {"push_num", ui_push_num}, {"push_radii", ui_push_radii}, {"push_font", ui_push_font}, {"push_skin", ui_push_skin},
    {"push_theme", ui_push_theme}, {"push_icon", ui_push_icon}, {"pop", ui_pop}, {"custom", ui_custom}, {"canvas", ui_canvas},
    {"store", ui_store}, {"theme", ui_theme}, {"theme_make", ui_theme_make}, {"theme_preset", ui_theme_preset},
    {"scale", ui_scale}, {"config", ui_cfg}, {"bind", ui_bind}, {"anim", ui_anim}, {"anim_color", ui_anim_color},
    {"a11y", ui_a11y}, {"a11y_role", ui_a11y_role}, {"a11y_value", ui_a11y_value}, {"a11y_tree", ui_a11y_tree}, {NULL, NULL},
};

static const luaL_Reg th_methods[] = {
    {"dark", th_dark}, {"light", th_light}, {"make", th_make}, {"preset", th_preset}, {"icon", th_icon}, {"copy", th_copy},
    {"fields", th_fields_list}, {NULL, NULL},
};

static const luaL_Reg cfg_methods[] = {
    {"cursor", cfg_cursor}, {"keys", cfg_keys}, {"reset", cfg_reset}, {NULL, NULL},
};

static const luaL_Reg pacer_methods[] = {
    {"wait", pacer_wait}, {NULL, NULL},
};

static const luaL_Reg empty_methods[] = {
    {NULL, NULL},
};

static const luaL_Reg lib_funcs[] = {
    {"open", l_open}, {"open_app", l_open_app}, {"open_offscreen", l_open_offscreen}, {"parse_combo", l_parse_combo},
    {"send", l_send}, {"now_ms", l_now_ms}, {"pacer", l_pacer}, {"canvas", l_canvas_new}, {"radius", l_radius},
    {"bitmap_load", l_bitmap_load}, {"bitmap_from_bytes", l_bitmap_from_bytes}, {"bitmap_from_argb", l_bitmap_from_argb},
    {"bitmap_wrap", l_bitmap_wrap}, {"bitmap_error", l_bitmap_error}, {"font_load", l_font_load},
    {"font_from_bytes", l_font_from_bytes}, {"font_system", l_font_system}, {"measure", l_measure},
    {"line_height", l_line_height}, {"set_font", l_set_font}, {"font_count", l_font_count}, {"strerror", l_strerror},
    {"save_ppm", l_save_ppm}, {"theme", l_theme_new}, {"ease", l_ease}, {"text_dir", l_text_dir}, {"pixels", lg_pixels}, {"hash", lg_hash}, {"_layout", l_layout},
    {NULL, NULL},
};

LG_EXPORT int luaopen_goome(lua_State *L)
{
    lg_class(L, MT_G, g_methods, NULL, NULL, g_gc, NULL);
    lg_class(L, MT_CANVAS, cv_methods, cv_index, cv_newindex, cv_gc, NULL);
    lg_class(L, MT_IMAGE, im_methods, im_index, NULL, im_gc, NULL);
    lg_class(L, MT_PIX, pix_methods, pix_index, pix_newindex, pix_gc, pix_len);
    lg_class(L, MT_BMP, bmp_methods, bmp_index, NULL, bmp_gc, NULL);
    lg_class(L, MT_FONT, font_methods, font_index, NULL, font_gc, NULL);
    lg_class(L, MT_UI, ui_methods, NULL, NULL, ui_gc, NULL);
    lg_class(L, MT_THEME, th_methods, th_index, th_newindex, th_gc, NULL);
    lg_class(L, MT_CFG, cfg_methods, cfg_index, cfg_newindex, cfg_gc, NULL);
    lg_class(L, MT_PACER, pacer_methods, NULL, NULL, NULL, NULL);
    lg_class(L, MT_STORE, empty_methods, st_index, st_newindex, st_gc, st_len);
    lg_closer(L, MT_G, g_close);
    lg_closer(L, MT_UI, ui_close);
    lg_closer(L, MT_BMP, bmp_close);
    lg_closer(L, MT_FONT, font_close);
    lua_newtable(L);
    lg_setfuncs(L, lib_funcs);
    for (const lg_const *c = lg_consts; c->name; c++) {
        lua_pushinteger(L, c->value);
        lua_setfield(L, -2, c->name);
    }
    lua_pushstring(L, GOOME_VERSION);
    lua_setfield(L, -2, "VERSION");
    if (luaL_loadbuffer(L, lg_app_lua, sizeof(lg_app_lua) - 1, "=goome.app")) lua_error(L);
    lua_pushvalue(L, -2);
    lua_call(L, 1, 0);
    return 1;
}
