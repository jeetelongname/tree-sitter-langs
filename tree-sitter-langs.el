;;; tree-sitter-langs.el --- Grammar bundle for tree-sitter -*- lexical-binding: t; coding: utf-8 -*-

;; Copyright (C) 2021 Tuấn-Anh Nguyễn
;;
;; Author: Tuấn-Anh Nguyễn <ubolonton@gmail.com>
;; Keywords: languages tools parsers tree-sitter
;; Homepage: https://github.com/emacs-tree-sitter/tree-sitter-langs
;; Version: 0.10.5
;; Package-Requires: ((emacs "25.1") (tree-sitter "0.15.0"))
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; This is a convenient language bundle for the Emacs package `tree-sitter'. It
;; serves as an interim distribution mechanism, until `tree-sitter' is
;; widespread enough for language-specific major modes to incorporate its
;; functionalities.
;;
;; For each supported language, this package provides:
;;
;; 1. Pre-compiled grammar binaries for 3 major platforms: macOS, Linux and
;;    Windows, on x86_64. In the future, `tree-sitter-langs' may provide tooling
;;    for major modes to do this on their own.
;;
;; 2. Optional highlighting patterns. This is mainly intended for major modes
;;    that are not aware of `tree-sitter'. A language major mode that wants to
;;    use `tree-sitter' for syntax highlighting should instead provide the query
;;    patterns on its own, using the mechanisms defined by `tree-sitter-hl'.
;;
;; 3. Optional query patterns for other minor modes that provide high-level
;;    functionalities on top of `tree-sitter', such as code folding, evil text
;;    objects... As with highlighting patterns, major modes that are directly
;;    aware of `tree-sitter' should provide the query patterns on their own.


;;; Code:

(require 'cl-lib)

(require 'tree-sitter)
(require 'tree-sitter-load)
(require 'tree-sitter-hl)

(require 'tree-sitter-langs-build)

(eval-when-compile
  (require 'pcase))

;; Not everyone uses a package manager that properly checks dependencies. We check it ourselves, and
;; ask users to upgrade `tree-sitter' if necessary. Otherwise, they would get `tsc-lang-abi-too-new'
;; errors, without an actionable message.
(let ((min-version "0.15.0"))
  (when (version< tsc-dyn--version min-version)
    (display-warning 'tree-sitter-langs
                     (format "Please upgrade `tree-sitter'. This bundle requires version %s or later." min-version)
                     :emergency)))

(defgroup tree-sitter-langs nil
  "Grammar bundle for `tree-sitter'."
  :group 'tree-sitter)

(defvar tree-sitter-langs--testing)
(eval-and-compile
  (unless (bound-and-true-p tree-sitter-langs--testing)
    (tree-sitter-langs-install-grammars :skip-if-installed)))

(defun tree-sitter-langs-ensure (lang-symbol)
  "Return the language object identified by LANG-SYMBOL.
If it cannot be loaded, this function tries to compile the grammar.

This function also tries to copy highlight query from the language repo, if it
exists.

See `tree-sitter-langs-repos'."
  (unwind-protect
      (condition-case nil
          (tree-sitter-require lang-symbol)
        (error
         (display-warning 'tree-sitter-langs
                          (format "Could not load grammar for `%s', trying to compile it"
                                  lang-symbol))
         (tree-sitter-langs-compile lang-symbol)
         (tree-sitter-require lang-symbol)))
    (tree-sitter-langs--copy-query lang-symbol)))

;;; Add the bundle directory.
(cl-pushnew (tree-sitter-langs--bin-dir)
            tree-sitter-load-path)

;;; Link known major modes to languages in the bundle.
(pcase-dolist
    (`(,major-mode . ,lang-symbol)
     (reverse '((agda-mode       . agda)
                (sh-mode         . bash)
                (c-mode          . c)
                (csharp-mode     . c-sharp)
                (c++-mode        . cpp)
                (css-mode        . css)
                (elm-mode        . elm)
                (go-mode         . go)
                (hcl-mode        . hcl)
                (html-mode       . html)
                (mhtml-mode      . html)
                (java-mode       . java)
                (javascript-mode . javascript)
                (js-mode         . javascript)
                (js2-mode        . javascript)
                (js3-mode        . javascript)
                (json-mode       . json)
                (jsonc-mode      . json)
                (julia-mode      . julia)
                (ocaml-mode      . ocaml)
                (php-mode        . php)
                (python-mode     . python)
                (pygn-mode       . pgn)
                (rjsx-mode       . javascript)
                (ruby-mode       . ruby)
                (rust-mode       . rust)
                (rustic-mode     . rust)
                (scala-mode      . scala)
                (swift-mode      . swift)
                (tuareg-mode     . ocaml)
                (typescript-mode . typescript))))
  (setf (map-elt tree-sitter-major-mode-language-alist major-mode)
        lang-symbol))

(defun tree-sitter-langs--hl-query-path (lang-symbol)
  (concat (file-name-as-directory
           (concat tree-sitter-langs--queries-dir
                   (symbol-name lang-symbol)))
          "highlights.scm"))

(defun tree-sitter-langs--hl-default-patterns (lang-symbol)
  "Return the bundled default syntax highlighting patterns for LANG-SYMBOL.
Return nil if there are no bundled patterns."
  (condition-case nil
      (with-temp-buffer
        ;; TODO: Make this less ad-hoc.
        (dolist (sym (cons lang-symbol
                           (pcase lang-symbol
                             ('cpp '(c))
                             ('typescript '(javascript))
                             ('tsx '(typescript javascript))
                             (_ nil))))
          (insert-file-contents (tree-sitter-langs--hl-query-path sym))
          (goto-char (point-max))
          (insert "\n"))
        (buffer-string))
    (file-missing nil)))

(defun tree-sitter-langs--set-hl-default-patterns (&rest _args)
  "Use syntax highlighting patterns provided by `tree-sitter-langs'."
  (unless tree-sitter-hl-default-patterns
    (let ((lang-symbol (tsc--lang-symbol tree-sitter-language)))
      (setq tree-sitter-hl-default-patterns
            (tree-sitter-langs--hl-default-patterns lang-symbol)))))

(advice-add 'tree-sitter-hl--setup :before
            #'tree-sitter-langs--set-hl-default-patterns)

(provide 'tree-sitter-langs)
;;; tree-sitter-langs.el ends here
