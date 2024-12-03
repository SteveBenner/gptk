# Changelog

## 0.6
- Added `Book::revise_chapter1` which represents a totally new system for interactively revising chapter content, analyzing for bad patterns and then, either altering the text content, removing the match entirely, or simply ignoring the match.
- Includes a 'batch method' which allows the user to choose either 'alter', 'remove', or 'ignore' for ALL found bad patterns at once and addresses them in a batch instead of interactively.
- Added a `Utils` module for extra goodies

## 0.5 - 2024.11.27
- Revised `Book` to take an Array of clients instead of just one, and updated client code accordingly
- Added the 'zipper' technique to the `Book` module, including the `::generate_zipper` and `::generate_chapter_zipper` methods which implement a back-and-forth means of generating content utilizing one or more AI's instead of just one.