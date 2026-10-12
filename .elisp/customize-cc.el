;;; -*- lexical-binding: t; -*-
(defvar dld-tab-stop-list '(4 8 12 16 20 24 28 32 36 40 44 48 52 56 60 64 68 72 76 80
)
  "List of tab stop posititions used in `tab-to-comment-stops'")

(defun dld-tab-to-tab-stop ()
  "Insert spaces or tabs to next defined tab-stop column.
The `dld-tab-stop-list' is a list of columns to stop at in c-mode."
  (interactive)
  (let ((old-tab-stop-list tab-stop-list))
    (setq tab-stop-list dld-tab-stop-list)
    (tab-to-tab-stop)
    (setq tab-stop-list old-tab-stop-list)
    ))

(defun dld-c-indent-command (&optional whole-exp)
  "Indent current line as C++ code, or in some cases insert a tab character.

If `c-tab-always-indent' is t, always just indent the current line.
If nil, indent the current line only if point is at the left margin or
in the line's indentation; otherwise insert a tab.  If other than nil
or t, then tab is inserted only within literals (comments and strings)
and inside preprocessor directives, but line is always reindented.

A numeric argument, regardless of its value, means indent rigidly all
the lines of the expression starting after point so that this line
becomes properly indented.  The relative indentation among the lines
of the expression are preserved."
  (interactive "P")
  (let ((bod (c-point 'bod)))
    (if whole-exp
	;; If arg, always indent this line as C
	;; and shift remaining lines of expression the same amount.
	(let ((shift-amt (c-indent-line))
	      beg end)
	  (save-excursion
	    (if (eq c-tab-always-indent t)
		(beginning-of-line))
	    (setq beg (point))
	    (forward-sexp 1)
	    (setq end (point))
	    (goto-char beg)
	    (forward-line 1)
	    (setq beg (point)))
	  (if (> end beg)
	      (indent-code-rigidly beg end (- shift-amt) "#")))
      ;; No arg supplied, use c-tab-always-indent to determine
      ;; behavior
      (cond
       ;; CASE 1: indent when at column zero or in lines indentation,
       ;; otherwise insert a tab
       ((not c-tab-always-indent)
	(if (save-excursion
	      (skip-chars-backward " \t")
	      (not (bolp)))
	    (dld-tab-to-tab-stop)
	  (c-indent-line)))
       ;; CASE 2: just indent the line
       ((eq c-tab-always-indent t)
	(c-indent-line))
       ;; CASE 3: if in a literal, insert a tab, but always indent the
       ;; line
       (t
	(if (c-in-literal bod)
	    (c-tab-to-tab-stop))
	(c-indent-line)
	)))))

(defun dld-indent-command-or-region ()
  "Indents the current line or region.

If a region is not active, indent the current line.  If a region is
active indent the region."
  (interactive)
  (dld-c-indent-command)
  )

(defconst dld-c-style
  '("PERSONAL"
    (c-tab-always-indent           . nil)
    (c-comment-only-line-offset    . 4)
    (c-hanging-braces-alist        . ((block-open  nil)
				      (brace-list-open  nil)))
    (c-hanging-colons-alist        . ((member-init-intro before)
				      (inher-intro)
				      (case-label after)
				      (label after)
				      (access-key after)))
    (c-cleanup-list                . (scope-operator
				      empty-defun-braces
				      defun-close-semi))
    ;; Do my own custom indenting.
    (c-offsets-alist               . ((knr-argdecl-intro . 0)
				      (case-label . +)
				      (substatement-open . 0)
				      (block-open . 0)
				      (comment-intro . 0)
				      (arglist-close . c-lineup-arglist)
				      (access-label . -2)
				      (inline-open . 0)
				      (topmost-intro-cont . +)
				      (innamespace . 0)
				      ))
    )
  "Dave's C, C++, and Java Programming Style")

;;
;; Customizations for both c-mode and c++-mode
;;
(defun	dld-cc-mode-hook ()
  "Hook for all cc-mode stuff"
  (let ((my-style "PERSONAL"))
    (or (assoc my-style c-style-alist)
	(setq c-style-alist (cons dld-c-style c-style-alist)))
    (c-set-style my-style))
	     
  ;; other customizations
  (setq tab-width 8
	c-basic-offset 4
	;; This will make sure spaces are used instead of tabs
	indent-tabs-mode nil
	c-hanging-comment-starter-p nil
	c-hanging-comment-ender-p nil)
  ;; We don't like auto-newline and hungry-delete
  (message "No tabs...")
  (c-toggle-auto-hungry-state -1)
	     
  ;; Keybindings.  Put common key bindings in c-mode-base-map.
  (define-key c-mode-base-map "\t" 'dld-indent-command-or-region)
  (define-key c-mode-base-map [return] 'newline-and-indent)
  (define-key c-mode-base-map "\C-c\C-c" 'nil)
  )

(add-hook 'c-mode-hook 'dld-cc-mode-hook)
(add-hook 'c++-mode-hook 'dld-cc-mode-hook)
(add-hook 'java-mode-hook 'dld-cc-mode-hook)
