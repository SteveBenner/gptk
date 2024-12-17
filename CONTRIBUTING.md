
# Contributing to GPTK

Thank you for your interest in contributing to **GPTK**! We welcome contributions of all kinds—whether you're reporting a bug, suggesting a new feature, improving the documentation, or writing code.

This document outlines the guidelines for contributing to ensure a collaborative and efficient workflow.

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Features](#suggesting-features)
  - [Improving Documentation](#improving-documentation)
  - [Contributing Code](#contributing-code)
- [Development Workflow](#development-workflow)
- [Testing Your Changes](#testing-your-changes)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Style Guide](#style-guide)
- [Community Support](#community-support)

## How to Contribute

### Reporting Bugs

If you encounter a bug, please:
1. Check the [issue tracker](https://github.com/SteveBenner/gptk/issues) to see if it has already been reported.
2. If not, create a new issue and include:

   - A clear title and description of the bug.
   - Steps to reproduce the issue.
   - Expected behavior and actual results.
   - Relevant environment details (Ruby version, OS, etc.).

### Suggesting Features

We’re always open to new ideas! To suggest a feature:
1. Check the [issue tracker](https://github.com/SteveBenner/gptk/issues) for similar suggestions.
2. If not found, open a feature request and include:

   - A clear and concise description of the feature.
   - The problem it solves or the value it adds.
   - Any relevant examples or references.

### Improving Documentation

Well-written documentation is crucial. You can help by:

- Fixing typos or improving clarity.
- Adding examples to existing sections.
- Proposing new documentation topics.

Feel free to submit a pull request or open an issue to discuss potential changes.

### Contributing Code

We welcome contributions to improve the library's functionality or performance. Before you start:

1. Check the [issue tracker](https://github.com/SteveBenner/gptk/issues) for similar proposals.
2. Comment on the issue to indicate your interest in working on it.
3. Ensure your changes align with the library’s goals and roadmap.
4. Ensure any new features integrate with the current architecture (`ai.rb`, `book.rb`, etc.).

## Development Workflow

### Setting Up the Project

1. Fork the repository to your account.
2. Clone the forked repository:

   ```bash
   git clone https://github.com/your-username/gptk.git
   cd gptk
   ```
3. Install dependencies:

   ```bash
   bundle install
   ```

## Pull Request Guidelines

1. **Branching:**
   - Create a new branch for each contribution:
   
     ```bash
     git checkout -b feature/my-new-feature
     ```
   - Use descriptive branch names (`bugfix/issue-123` or `feature/add-text-analysis`).

2. **Commits:**
   - Write clear, concise commit messages.
   - Use conventional commit messages:
     - `feat:` for new features.
     - `fix:` for bug fixes.
     - `docs:` for documentation changes.
     - `test:` for adding or improving tests.

3. **Before Submitting:**
   - Lint your code:
     ```bash
     rubocop
     ```
   - Ensure all tests pass.
   - Squash commits if necessary to maintain a clean history.

4. **Submit the PR:**
   - Push your branch to your fork:
     ```bash
     git push origin feature/my-new-feature
     ```
   - Open a pull request against the `main` branch.
   - Include the following in the PR description:
     - A summary of changes.
     - A link to the related issue.
     - Any additional context or considerations.

---

## Style Guide

### Code Style
- Follow [Ruby Style Guide](https://rubystyle.guide/).
- Use consistent formatting:
  - Indentation: 2 spaces.
  - Line length: 80 characters maximum.
- Document methods with YARD-style comments:

  ```ruby
  # Generates a chapter of the book.
  #
  # @param [String] outline The book outline.
  # @return [String] The generated chapter.
  def generate_chapter(outline)
    # ...
  end
  ```

### Directory Structure
- **`lib/gptk`:** Core library code.
- **`prompts`:** Training data and templates.
- **`docs`:** Additional documentation files.

## Community Support

Need help or have questions? Reach out:

- Open an issue on [GitHub](https://github.com/your-username/gptk/issues).
- Join the community discussion on the repository’s `Discussions` tab (if enabled).
