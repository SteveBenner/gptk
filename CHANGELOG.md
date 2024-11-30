# Changelog

## 0.5 - 2024.11.27
- Revised `Book` to take an Array of clients instead of just one, and updated client code accordingly
- Added the 'zipper' technique to the `Book` module, including the `::generate_zipper` and `::generate_chapter_zipper` methods which implement a back-and-forth means of generating content utilizing one or more AI's instead of just one.