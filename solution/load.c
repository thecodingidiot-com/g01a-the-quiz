#include "game.h"

static void encode_pipes(char *s)
{
    char *r;
    char *w;

    r = s;
    w = s;
    while (*r) {
        if (r[0] == '|' && r[1] == '|') {
            *w++ = '\x01';  /* C0 control byte — cannot appear in valid UTF-8 text */
            r += 2;
        } else {
            *w++ = *r++;
        }
    }
    *w = '\0';              /* loop exits before the null terminator is copied */
}

static void decode_pipes(char **fields)
{
    int   i;
    char *p;

    for (i = 0; fields[i]; i++) {
        for (p = fields[i]; *p; p++) {
            if (*p == '\x01')
                *p = '|';
        }
    }
}

/*
** tciu_split returns a NULL-terminated array, and NULL-terminated is the
** whole of what it promises -- it does not report a length. So the only
** way to learn how many fields a line produced is to walk to the
** terminator. Asking "are there at least five?" by testing fields[4]
** reads past the end of any shorter array, which is undefined behaviour:
** on a line with one field the array holds two pointers, and fields[4] is
** sixteen bytes beyond it.
*/
static int  count_fields(char **fields)
{
    int i;

    i = 0;
    while (fields[i])
        i++;
    return (i);
}

/* Both exits from the loop below need this: the array AND every string
** in it. Freeing only the array leaks each field. */
static void free_fields(char **fields)
{
    int i;

    i = 0;
    while (fields[i])
        free(fields[i++]);
    free(fields);
}

question_t  **load_questions(const char *path, int *count)
{
    int         fd;
    char        *line;
    char        *nl;
    char        **fields;
    question_t  **questions;
    question_t  *q;
    int         capacity;

    fd = open(path, O_RDONLY);
    if (fd < 0) {
        tci_printf("error: cannot open '%s'\n", path);
        return (NULL);
    }
    questions = NULL;
    *count = 0;
    capacity = 0;
    while ((line = tci_getline(fd)) != NULL) {
        nl = tci_strchr(line, '\n');
        if (nl)
            *nl = '\0';
        encode_pipes(line);
        fields = tciu_split(line, '|');
        free(line);
        if (!fields)
            continue;
        if (count_fields(fields) < FIELDS_REQUIRED) {
            free_fields(fields);
            continue;
        }
        decode_pipes(fields);
        if (*count == capacity) {
            capacity = capacity ? capacity * 2 : 16;
            questions = realloc(questions, capacity * sizeof(question_t *));
        }
        q = tci_calloc(1, sizeof(question_t));
        q->text    = tci_strdup(fields[0]);
        q->opts[0] = tci_strdup(fields[1]);
        q->opts[1] = tci_strdup(fields[2]);
        q->opts[2] = tci_strdup(fields[3]);
        q->opts[3] = tci_strdup(fields[4]);
        q->answer  = fields[5] ? fields[5][0] - '0' : 0;
        q->hint    = (fields[6] && fields[6][0])
                     ? tci_strdup(fields[6])
                     : NULL;
        questions[(*count)++] = q;
        free_fields(fields);
    }
    close(fd);
    return (questions);
}

void    free_questions(question_t **questions, int count)
{
    int  i;
    int  j;

    if (!questions)
        return;
    for (i = 0; i < count; i++) {
        free(questions[i]->text);
        for (j = 0; j < 4; j++)
            free(questions[i]->opts[j]);
        free(questions[i]->hint);
        free(questions[i]);
    }
    free(questions);
}
