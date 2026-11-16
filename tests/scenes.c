#define GOOME_IMPLEMENTATION
#include "goome.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint32_t sc_fnv(const uint32_t *sc_px, int w, int h, int stride)
{
    uint32_t v = 2166136261u;
    for (int y = 0; y < h; y++)
        for (int x = 0; x < w; x++) {
            uint32_t p = sc_px[(size_t)y * stride + x];
            for (int k = 0; k < 4; k++) v = (v ^ ((p >> (k * 8)) & 255)) * 16777619u;
        }
    return v;
}

static goome_font *sc_load(const char *dir, const char *name)
{
    char p[1024];
    snprintf(p, sizeof(p), "%s/%s", dir, name);
    return goome_font_load(p);
}

typedef struct {
    goome *g;
    goome_ui *u;
    int on;
    uint32_t hash;
} sc_am_t;

static void sc_am_frame(sc_am_t *k)
{
    goome_event ev;
    while (goome_poll(k->g, &ev, 0) > 0) goome_ui_feed(k->u, &ev);
    goome_canvas *c = goome_ui_begin(k->u, 0);
    if (!c) return;
    goome_canvas *r = goome_ui_canvas(k->u);
    double box = goome_ui_anim(k->u, "box", k->on ? 200 : 10, 160, GOOME_EASE_OUT);
    double sp = goome_ui_anim(k->u, "spring", k->on ? 1 : 0, 320, GOOME_EASE_SPRING);
    uint32_t col = goome_ui_anim_color(k->u, "col", k->on ? 0xFF20D060u : 0x00000000u, 200, GOOME_EASE_LINEAR);
    goome_ui_anim(k->u, "gone", k->on ? 5 : 0, 100, GOOME_EASE_LINEAR);
    if (r) {
        goome_draw_rect(r, box, 20, 60, 40, 0xFFE0A030u);
        goome_draw_rrect(r, 20 + sp * 180, 90, 50, 30, goome_radius(15), 0xFF4FB3F7u);
        goome_draw_rect(r, 20, 140, 260, 40, col);
    }
    goome_ui_end(k->u);
    k->hash = sc_fnv(c->px, c->w, c->h, c->stride);
}

static void sc_anims(void)
{
    int err;
    sc_am_t k;
    memset(&k, 0, sizeof(k));
    goome_opts o;
    memset(&o, 0, sizeof(o));
    o.backend = GOOME_TEST, o.mode = GOOME_MODE_WINDOW, o.width = 300, o.height = 200, o.test_script = "end 100000";
    k.g = goome_open(&o, &err);
    k.u = goome_ui_new(k.g);
    sc_am_frame(&k);
    sc_am_frame(&k);
    uint32_t hs[4];
    k.on = 1;
    for (int f = 0; f < 60; f++) {
        sc_am_frame(&k);
        if (f == 1) hs[0] = k.hash;
        if (f == 4) hs[1] = k.hash;
        if (f == 8) hs[2] = k.hash;
    }
    hs[3] = k.hash;
    printf("anim %08x %08x %08x %08x\n", hs[0], hs[1], hs[2], hs[3]);
    goome_ui_free(k.u);
    goome_close(k.g);
}

static uint32_t sc_px[400 * 120];

static uint32_t sc_txt_hash(goome_font *f, double size, const char *s, uint32_t argb, int dir, int w, int h)
{
    goome_canvas c;
    memset(&c, 0, sizeof(c));
    memset(sc_px, 0, sizeof(sc_px));
    c.px = sc_px, c.w = w, c.h = h, c.stride = 400, c.scale = 1, c.kx1 = w, c.ky1 = h;
    goome_text_dir(dir);
    goome_text(&c, f, size, 4, 4, s, argb);
    goome_text_dir(GOOME_DIR_AUTO);
    return sc_fnv(sc_px, 400, 120, 400);
}

static void sc_emoji_rtl(const char *dir)
{
    goome_font *f = sc_load(dir, "colr.ttf"), *cb = sc_load(dir, "cbdt.ttf"), *sb = sc_load(dir, "sbix.ttf"), *d = sc_load(dir, "dejavu-sub.ttf");
    if (!f || !cb || !sb || !d) {
        printf("emoji fonts missing\n");
        return;
    }
    uint32_t got[6];
    got[0] = sc_txt_hash(f, 30, "ab \xF0\x9F\x98\x80 \xF0\x9F\x98\x80\xF0\x9F\x8F\xBB \xF0\x9F\x98\x80\xE2\x80\x8D\xF0\x9F\x98\x80 \xE2\x9D\xA4 \xE2\x9D\xA4\xEF\xB8\x8F", 0xFF2040A0, 0, 400, 60);
    goome_canvas c;
    memset(&c, 0, sizeof(c));
    memset(sc_px, 0, sizeof(sc_px));
    c.px = sc_px, c.w = 400, c.h = 120, c.stride = 400, c.scale = 1;
    goome_text(&c, cb, 16, 4, 4, "\xF0\x9F\x90\xB1", 0xFFFFFFFF);
    goome_text(&c, cb, 64, 30, 4, "\xF0\x9F\x90\xB1", 0xFFFFFFFF);
    goome_text(&c, sb, 40, 120, 4, "\xF0\x9F\x90\xB1\xF0\x9F\x90\xB1", 0x80FFFFFF);
    got[1] = sc_fnv(sc_px, 400, 120, 400);
    goome_font_fallback(d, f);
    got[2] = sc_txt_hash(d, 20, "goome! \xF0\x9F\x98\x80 Hi", 0xFFFFFFFF, 0, 400, 40);
    got[3] = sc_txt_hash(f, 24, "ab \xD7\x90\xD7\x91\xD7\x92 (12) c", 0xFFFFFFFF, 0, 400, 40);
    got[4] = sc_txt_hash(f, 24, "ab \xD7\x90\xD7\x91\xD7\x92 (12) c", 0xFFFFFFFF, GOOME_DIR_RTL, 400, 40);
    got[5] = sc_txt_hash(f, 30, "\xD8\xA8\xD9\x84\xD8\xA7\xD9\x85 \xD8\xA8\xD8\xA8\xD8\xA8 \xD9\x84\xD9\x85 \xD8\xA8\xD9\x8E\xD8\xA8", 0xFFFFFFFF, 0, 400, 50);
    printf("emoji %08x %08x %08x %08x %08x %08x\n", got[0], got[1], got[2], got[3], got[4], got[5]);
    printf("measure %.3f %.3f\n", goome_text_measure(d, 20, "goome! \xF0\x9F\x98\x80", NULL),
           goome_text_measure(f, 20, "\xD8\xA8\xD9\x84\xD8\xA7\xD9\x85 \xD8\xA8\xD8\xA8\xD8\xA8 \xD9\x84\xD9\x85", NULL));
    goome_font_free(d);
    goome_font_free(sb);
    goome_font_free(cb);
    goome_font_free(f);
}

typedef struct {
    goome *g;
    goome_ui *u;
    char in[64], ed[96];
    uint32_t hash;
} sc_im_t;

static void sc_im_frame(sc_im_t *k, int focus)
{
    goome_event ev;
    while (goome_poll(k->g, &ev, 0) > 0) goome_ui_feed(k->u, &ev);
    goome_canvas *c = goome_ui_begin(k->u, 0);
    if (!c) return;
    if (focus == 1) goome_ui_set_focus(k->u);
    goome_ui_input_ex(k->u, "in", k->in, sizeof(k->in), GOOME_INPUT_NO_SELECT_ON_FOCUS, NULL);
    if (focus == 2) goome_ui_set_focus(k->u);
    goome_ui_text_edit(k->u, "ed", k->ed, sizeof(k->ed), 80, 0);
    goome_ui_end(k->u);
    k->hash = sc_fnv(c->px, c->w, c->h, c->stride);
}

static void sc_im_open(sc_im_t *k, const char *in, const char *ed, int focus)
{
    int err;
    memset(k, 0, sizeof(*k));
    goome_opts o;
    memset(&o, 0, sizeof(o));
    o.backend = GOOME_TEST, o.mode = GOOME_MODE_WINDOW, o.width = 300, o.height = 200, o.test_script = "end 100000";
    k->g = goome_open(&o, &err);
    k->u = goome_ui_new(k->g);
    goome_theme *t = goome_ui_theme(k->u);
    t->font = NULL, t->font_size = 14, t->anim_ms = 0;
    goome_ui_cfg(k->u)->blink_ms = 0;
    snprintf(k->in, sizeof(k->in), "%s", in);
    snprintf(k->ed, sizeof(k->ed), "%s", ed);
    sc_im_frame(k, focus);
    sc_im_frame(k, 0);
}

static void sc_im_push(sc_im_t *k, int type, const char *s, int cur)
{
    goome_event e;
    memset(&e, 0, sizeof(e));
    e.type = type, e.id = cur;
    snprintf(e.msg, sizeof(e.msg), "%s", s);
    goome_push(k->g, &e);
    sc_im_frame(k, 0);
}

static void sc_ime(void)
{
    sc_im_t k;
    uint32_t h[4], edh;
    sc_im_open(&k, "ab", "", 1);
    h[0] = k.hash;
    sc_im_push(&k, GOOME_PREEDIT, "xyz", 1);
    h[1] = k.hash;
    sc_im_push(&k, GOOME_PREEDIT, "xyz", 3);
    h[2] = k.hash;
    sc_im_push(&k, GOOME_PREEDIT, "", 0);
    sc_im_push(&k, GOOME_TEXT, "\xE6\x97\xA5\xE6\x9C\xAC", 0);
    printf("commit %s\n", k.in);
    goome_ui_free(k.u);
    goome_close(k.g);
    sc_im_open(&k, "", "line", 2);
    h[3] = k.hash;
    sc_im_push(&k, GOOME_PREEDIT, "kana", 2);
    edh = k.hash;
    sc_im_push(&k, GOOME_PREEDIT, "", 0);
    sc_im_push(&k, GOOME_TEXT, "\xE3\x81\x8B\xE3\x81\xAA\n", 0);
    goome_ui_free(k.u);
    goome_close(k.g);
    printf("ime %08x %08x %08x %08x %08x\n", h[0], h[1], h[2], h[3], edh);
}

typedef struct {
    goome *g;
    goome_ui *u;
    int ok, dark, mode, fruit, tab, open;
    double vol;
    char name[64], note[256];
    goome_a11y_node n[256];
    int count;
} sc_ax_t;

static void sc_ax_frame(sc_ax_t *k)
{
    static const char *const fruits[] = {"Mango", "Kiwi", "Fig"};
    static const char *const tabs[] = {"One", "Two"};
    goome_event ev;
    while (goome_poll(k->g, &ev, 0) > 0) goome_ui_feed(k->u, &ev);
    if (!goome_ui_begin(k->u, 0)) return;
    goome_ui_app(k->u, "Demo", GOOME_APP_TITLEBAR | GOOME_APP_STATUSBAR);
    goome_ui_label(k->u, "Hello there");
    if (goome_ui_button(k->u, "OK")) k->ok++;
    goome_ui_checkbox(k->u, "Dark", &k->dark);
    goome_ui_radio(k->u, "Big", &k->mode, 1);
    goome_ui_slider(k->u, "Volume", &k->vol, 0, 10, "%.1f");
    goome_ui_input(k->u, "Name", k->name, sizeof(k->name));
    goome_ui_combo(k->u, "Fruit", &k->fruit, fruits, 3);
    goome_ui_tabs(k->u, "tabs", tabs, 2, &k->tab);
    if (goome_ui_tree(k->u, "Folder", &k->open)) {
        goome_ui_label(k->u, "inside");
        goome_ui_tree_end(k->u);
    }
    goome_ui_progress(k->u, 0.25, NULL);
    goome_ui_text_edit(k->u, "Notes", k->note, sizeof(k->note), 60, 0);
    goome_ui_a11y_role(k->u, GOOME_ROLE_BUTTON, "Knob");
    goome_ui_a11y_value(k->u, "11");
    goome_ui_item it;
    goome_ui_custom(k->u, "knob", 40, 40, 0, &it);
    goome_ui_statusbar(k->u, "ready");
    goome_ui_app_end(k->u);
    goome_ui_end(k->u);
    k->count = goome_a11y_tree(k->u, k->n, 256);
}

static int sc_ax_find(sc_ax_t *k, int role, const char *label)
{
    for (int i = 0; i < k->count && i < 256; i++)
        if (k->n[i].role == role && !strcmp(k->n[i].label, label)) return i;
    return -1;
}

static void sc_ax_send(sc_ax_t *k, const char *verb, int i, const char *text)
{
    goome_event e;
    memset(&e, 0, sizeof(e));
    e.type = GOOME_CONTROL;
    if (i < 0) return;
    snprintf(e.msg, sizeof(e.msg), "a11y %s %u%s%s", verb, (unsigned)k->n[i].id, text ? " " : "", text ? text : "");
    goome_push(k->g, &e);
}

static void sc_ax_dump(sc_ax_t *k, const char *tag)
{
    printf("%s %d\n", tag, k->count);
    for (int i = 0; i < k->count && i < 256; i++) {
        goome_a11y_node *n = &k->n[i];
        printf("%d %d %d %.3f %.3f %.3f %.3f [%s] [%s] %u %.3f %.3f %.3f %d\n", n->role, n->parent, n->states, n->x, n->y, n->w, n->h,
               n->label, n->value, (unsigned)n->id, n->num, n->min, n->max, n->caret);
    }
}

static void sc_a11y(void)
{
    int err;
    sc_ax_t k;
    memset(&k, 0, sizeof(k));
    k.vol = 2;
    snprintf(k.name, sizeof(k.name), "Bo");
    goome_opts o;
    memset(&o, 0, sizeof(o));
    o.backend = GOOME_TEST, o.mode = GOOME_MODE_WINDOW, o.width = 420, o.height = 700, o.test_script = "end 100000";
    k.g = goome_open(&o, &err);
    k.u = goome_ui_new(k.g);
    goome_ui_theme(k.u)->font = NULL;
    sc_ax_frame(&k);
    sc_ax_dump(&k, "a11y");
    sc_ax_send(&k, "press", sc_ax_find(&k, GOOME_ROLE_BUTTON, "OK"), NULL);
    sc_ax_send(&k, "press", sc_ax_find(&k, GOOME_ROLE_CHECKBOX, "Dark"), NULL);
    sc_ax_send(&k, "set", sc_ax_find(&k, GOOME_ROLE_SLIDER, "Volume"), "7.5");
    sc_ax_send(&k, "set", sc_ax_find(&k, GOOME_ROLE_INPUT, "Name"), "hello there");
    sc_ax_send(&k, "expand", sc_ax_find(&k, GOOME_ROLE_TREE, "Folder"), NULL);
    sc_ax_send(&k, "press", sc_ax_find(&k, GOOME_ROLE_TAB, "Two"), NULL);
    sc_ax_frame(&k);
    sc_ax_frame(&k);
    printf("state %d %d %.3f %s %d %d\n", k.ok, k.dark, k.vol, k.name, k.open, k.tab);
    sc_ax_dump(&k, "a11y after");
    goome_ui_free(k.u);
    goome_close(k.g);
}

int main(int argc, char **argv)
{
    sc_anims();
    sc_emoji_rtl(argc > 1 ? argv[1] : "tests/data");
    sc_ime();
    sc_a11y();
    return 0;
}
