;;; lox-ts-mode.el --- Major mode for Lox using tree-sitter -*- lexical-binding: t; -*-

;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/lox-ts-mode
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Created: 22 July 2024
;; Keywords: lox, tree-sitter, languages

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:
;;
;; Major mode for Lox buffers using tree-sitter.
;;
;; Lox is the language developed over the course of the Crafting Interpreters
;; book. For details, see
;; https://craftinginterpreters.com/the-lox-language.html.
;;
;; Make sure to install the parser compatible with this library from
;; https://github.com/nverno/tree-sitter-lox.
;;
;;; Code:

(require 'treesit)


(defcustom lox-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `lox-ts-mode'."
  :type 'integer
  :safe 'integerp
  :group 'lox)


;;; Syntax

(defvar lox-ts-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?\\ "\\" st)
    (modify-syntax-entry ?\^m "> b" st)
    (modify-syntax-entry ?\n "> b" st)
    (modify-syntax-entry ?+  "." st)
    (modify-syntax-entry ?-  "." st)
    (modify-syntax-entry ?=  "." st)
    (modify-syntax-entry ?<  "." st)
    (modify-syntax-entry ?>  "." st)
    st)
  "Syntax table for `lox-ts-mode'.")


;;; Indentation

(defvar lox-ts-mode--indent-rules
  `((lox
     ((parent-is "program") column-0 0)
     ((node-is "}") standalone-parent 0)
     ((node-is ")") parent-bol 0)
     ((node-is "else_clause") parent-bol 0)
     ((node-is "superclass") parent-bol lox-ts-mode-indent-offset)
     ((parent-is "parenthesized_expression")
      standalone-parent lox-ts-mode-indent-offset)
     ((parent-is
       ,(rx bol (or "class_body"
                    "superclass"
                    "compound_statement"
                    "variable_declaration"
                    "if_statement" "else_clause"
                    "for_statement" "for_clause"
                    "while_statement"
                    "print_statement"
                    "return_statement"
                    "parameter_list" "argument_list"
                    "binary_expression"
                    "member_expression")
            eol))
      parent-bol lox-ts-mode-indent-offset)
     ;; Rule for statements with unbracketed bodies
     ((parent-is ,(rx bol (or "if_statement" "else_clause"
                              "for_statement" "while_statement")
                      eol))
      standalone-parent lox-ts-mode-indent-offset)
     (catch-all parent-bol 0)))
  "Tree-sitter indent rules for Lox.")


;;; Font-locking

(defconst lox-ts-mode--keywords
  '("and" "class" "else" "for" "fun" "if" "or" "print" "return" "super"
    "var" "while")
  "Lox keywords for tree-sitter font-locking.")

(defconst lox-ts-mode--builtins
  '("clock")
  "Lox builtin functions to tree-sitter font-locking.")

(defconst lox-ts-mode--operators
  '("-" "!" "+" "*" "/" "<" ">" "<=" ">=" "==" "!=" "=")
  "Lox operators for tree-sitter font-locking.")

(defun lox-ts-mode--fontify-call-expression (node override start end &rest _args)
  "Fontify function call expressions in NODE.
For OVERRIDE, START, END, see `treesit-font-lock-rules'."
  (pcase (treesit-node-type node)
    ("call_expression"
     (lox-ts-mode--fontify-call-expression
      (treesit-node-child-by-field-name node "function") override start end))
    ("super_expression"
     (lox-ts-mode--fontify-call-expression
      (treesit-node-child node 0 t) override start end))
    ("member_expression"
     (lox-ts-mode--fontify-call-expression
      (treesit-node-child-by-field-name node "property") override start end))
    ("identifier"
     (treesit-fontify-with-override
      (treesit-node-start node) (treesit-node-end node)
      'font-lock-function-call-face
      override start end))
    (_ nil)))

(defvar lox-ts-mode-feature-list
  '(( comment definition)
    ( keyword string)
    ( builtin constant function number property)
    ( assignment bracket delimiter operator variable))
  "Font-locking features for `treesit-font-lock-feature-list' in `lox-ts-mode'.")

(defvar lox-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'lox
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'lox
   :feature 'string
   '((string) @font-lock-string-face)

   :language 'lox
   :feature 'keyword
   `([,@lox-ts-mode--keywords (this)] @font-lock-keyword-face)

   :language 'lox
   :feature 'operator
   `([,@lox-ts-mode--operators] @font-lock-operator-face)

   :language 'lox
   :feature 'definition
   '((class_declaration
      name: (identifier) @font-lock-type-face
      (superclass (identifier) @font-lock-type-face) :?)
     (function_declaration
      name: (identifier) @font-lock-function-name-face)
     (method_definition
      name: (identifier) @font-lock-function-name-face)
     (variable_declaration
      name: (identifier) @font-lock-variable-name-face)
     (parameter_list [(identifier)] @font-lock-variable-name-face)
     (binary_expression
      left: (member_expression
             object: (this)
             property: (identifier) @font-lock-property-name-face)
      operator: "="))

   :language 'lox
   :feature 'constant
   '([(true) (false) (nil)] @font-lock-constant-face)

   :language 'lox
   :feature 'builtin
   `((call_expression
      function: ((identifier) @font-lock-builtin-face
                 (:match ,(rx-to-string
                           `(seq bol (or ,@lox-ts-mode--builtins) eol))
                         @font-lock-builtin-face))))

   :language 'lox
   :feature 'function
   '((call_expression) @lox-ts-mode--fontify-call-expression)

   :language 'lox
   :feature 'property
   '((member_expression
      ;; object: (this)
      property: (identifier) @font-lock-property-use-face))

   :language 'lox
   :feature 'variable
   '((argument_list [(identifier)] @font-lock-variable-use-face))

   :language 'lox
   :feature 'number
   '((number) @font-lock-number-face)

   :language 'lox
   :feature 'delimiter
   '([";" "," "."] @font-lock-delimiter-face)

   :language 'lox
   :feature 'bracket
   `(["{" "}" "(" ")"] @font-lock-bracket-face))
  "Tree-sitter font-lock settings for Lox.")


(defun lox-ts-mode--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or NODE is not a defun node."
  (pcase (treesit-node-type node)
    ((or "function_declaration"
         "method_definition"
         "class_declaration")
     (treesit-node-text
      (treesit-node-child-by-field-name node "name")
      t))))


;;;###autoload
(define-derived-mode lox-ts-mode prog-mode "Lox"
  "Major mode for editing Lox buffers using tree-sitter."
  :group 'lox
  :syntax-table lox-ts-mode-syntax-table

  (when (treesit-ready-p 'lox)
    (treesit-parser-create 'lox)

    ;; Comments
    (setq-local comment-start "// ")
    (setq-local comment-end "")
    (setq-local comment-start-skip (rx "//" (* (syntax whitespace))))

    ;; Electric
    (setq-local electric-layout-rules
                '((?\; . after) (?. . after) (?\{ . after) (?\} . before)))
    (setq-local electric-indent-chars (append "{}().;," electric-indent-chars))

    ;; Indentation
    (setq-local treesit-simple-indent-rules lox-ts-mode--indent-rules)

    ;; Font-Locking
    (setq-local treesit-font-lock-settings lox-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list lox-ts-mode-feature-list)

    ;; Navigation
    (setq-local treesit-defun-type-regexp
                (rx (or "class_declaration"
                        "function_declaration"
                        "method_definition")))

    (setq-local treesit-defun-name-function #'lox-ts-mode--defun-name)

    (setq-local treesit-thing-settings
                `((lox
                   ;; (sexp (not ,(rx (or "{" "}" "[" "]" "(" ")" ","))))
                   ;; Any nodes ending in _(statement|declaration)
                   (sentence
                    ,(rx "_" (or "statement" "declaration") eos))
                   (text ,(rx (or "comment" "string"))))))

    ;; Imenu
    (setq-local treesit-simple-imenu-settings
                `(("Class" "\\`class_declaration\\'")
                  ("Function" ,(rx bos (or "function_declaration"
                                           "method_definition")
                                   eos))))

    (treesit-major-mode-setup)))


(when (fboundp 'derived-mode-add-parents)
  (derived-mode-add-parents 'lox-ts-mode '(lox-mode)))

(if (treesit-ready-p 'lox)
    (add-to-list 'auto-mode-alist '("\\.lox\\'" . lox-ts-mode)))


(provide 'lox-ts-mode)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; lox-ts-mode.el ends here
