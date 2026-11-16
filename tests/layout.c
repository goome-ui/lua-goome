#include <stdio.h>
#include <stddef.h>

#include "goome.h"

#define S(t) printf("%s %d\n", #t, (int)sizeof(t))
#define F(t, f) printf("%s.%s %d %d\n", #t, #f, (int)offsetof(t, f), (int)sizeof(((t *)0)->f))

int main(void)
{
#include "../src/layout.h"
    return 0;
}
