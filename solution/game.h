#ifndef GAME_H
# define GAME_H

# include "libtci.h"
# include "libtciutil.h"
# include <fcntl.h>
# include <unistd.h>
# include <stdlib.h>
# include <time.h>

# define LEVELS  15

/* A question line is text|A|B|C|D, then an optional answer index and an
** optional hint. Five is the minimum that can produce a question. */
# define FIELDS_REQUIRED 5

typedef struct {
    char    *text;
    char    *opts[4];
    int      answer;
    char    *hint;
} question_t;

/* load.c */
question_t  **load_questions(const char *path, int *count);
void          free_questions(question_t **questions, int count);

/* display.c */
void    display_ladder(int level, int safe_level);
void    display_question(question_t *q, int hidden[4]);
void    display_audience(question_t *q);
void    display_win(void);
void    display_loss(int safe_level);
void    display_walkaway(int level);

/* display.c constants — accessible to game.c */
extern const char   *PRIZES[];
extern const int     SAFE[];

/* game.c */
void    game_loop(question_t **questions, int count);

#endif
