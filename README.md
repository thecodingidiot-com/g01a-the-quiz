# g01a — Who Wants to Be a Game Developer?

Build a terminal quiz game using `tci_printf` as the rendering engine — prize
ladder, three lifelines, fifteen questions, one million pounds.

---

## Follow my journey

Clone this repo and copy `test.sh` into your working directory. Work through
the chapter's implementation pages, building the game one layer at a time.
When you reach the final page, run the tester:

```bash
git clone https://github.com/thecodingidiot-com/g01a-the-developer.git
cp g01a-the-developer/test.sh ~/g01a-practice/
cd ~/g01a-practice
bash test.sh
```

---

## Follow your journey

The game loads questions from a plain text file, draws 15 at random, and runs
them as a prize-ladder quiz. The full project brief is in the chapter's
**Self** tab.

**Source files:**

| File        | Contents                                                       |
| ----------- | -------------------------------------------------------------- |
| `main.c`    | argument check, load, shuffle, game loop, free                 |
| `load.c`    | `load_questions()`, `free_questions()`                         |
| `display.c` | `display_ladder()`, `display_question()`, `display_audience()`, exit screens |
| `game.c`    | `game_loop()`, `read_input()`, `handle_lifeline()`             |

**Build:**

```bash
# Start from your c03 working directory (contains libtci.a and libtciutil.a)
cp -r ~/c03-practice ~/g01a-practice
cd ~/g01a-practice
# Add game.h, main.c, load.c, display.c, and game.c
make re
./game ../fixtures/questions.txt
```

The `solution/` directory contains the complete reference implementation
alongside a 30-question bank. The `fixtures/` directory contains the 15-question
file used by the tester.

---

## What the tester checks

Four test cases run sequentially:

1. **Full win** — correct answers to all 15 questions; expects the win screen.
2. **Early loss** — wrong answer on question 3 (before the first safe level);
   expects `£0`.
3. **50:50 lifeline** — uses the 50:50 lifeline on question 8, then answers
   correctly through to the win screen.
4. **Walk away** — walks at question 11 after passing the £32,000 safe level;
   expects `£32,000` as the banked amount.

The tester uses `fixtures/test-questions.txt` — 15 questions where option A is
always correct, so results are deterministic regardless of shuffle order.

---

## License

[MIT License](LICENSE)
