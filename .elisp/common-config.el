;;; common-config.el --- shared Emacs configuration  -*- lexical-binding: t; -*-
;;; emacs -Q --batch -f batch-byte-compile *.el

;;; Note: the custom-set-variables/custom-set-faces this file used to
;;; carry here were an exact duplicate of the ones in .emacs, which is
;;; the real Custom file (no custom-file is set, so Custom writes to
;;; the init file). Removed rather than kept in sync by hand.

(load "customize-cperl")
(load "customize-elisp")
(load "customize-cc")
(load "customize-ruby")
(load "customize-js")
(load "customize-sh")
(load "customize-css")
(load "customize-git")
(load "customize-web-mode")
(load "customize-whitespace")
(load "customize-nxml")
(require 'imenu)
(define-key global-map [(shift down-mouse-3)] 'imenu)
(setq imenu-sort-function 'imenu--sort-by-name)
(require 'cc-mode)
(setq mouse-yank-at-point t
      inhibit-startup-message t
      large-file-warning-threshold nil
      require-final-newline t
      next-line-add-newlines nil
      scroll-margin 5
      scroll-preserve-screen-position 1
      tags-revert-without-query 1
      make-backup-files nil ;;; Don't make backups
      )
(global-set-key "\C-cr" 'query-replace-regexp)
(setq use-short-answers t) ; stop forcing me to spell out "yes"
(line-number-mode 1)
(column-number-mode 1)
(show-smartparens-global-mode +1)

(add-hook 'prog-mode-hook 'rainbow-delimiters-mode)
(add-hook 'prog-mode-hook 'flyspell-prog-mode)

;;; Make highlighted regions act like a word processor
(delete-selection-mode 1)

;;; Allow us to use narrow-to-region
(put 'narrow-to-region 'disabled nil)

;;; automatically does a "chmod u+x" when you save a script file -
;;; note this fires on ANY saved file starting with #!, not just ones
;;; already executable, so the blast radius is every shebang'd file.
(add-hook 'after-save-hook
          'executable-make-buffer-file-executable-if-script-p)

(defun display-ansi-colors ()
  (interactive)
  (ansi-color-apply-on-region (point-min) (point-max)))


;;; customize flycheck temp file prefix
(setq-default flycheck-temp-prefix ".flycheck")
;; setting the xml parser seems to make javascript happier
(setq flycheck-xml-parser 'flycheck-parse-xml-region)
