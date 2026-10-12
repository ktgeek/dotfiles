;;; -*- lexical-binding: t; -*-
(defun ktg-emacs-lisp-mode-hook ()
  (define-key emacs-lisp-mode-map [return] 'newline-and-indent)
  (setq indent-tabs-mode nil)
  (aggressive-indent-mode)
  )

(add-hook 'emacs-lisp-mode-hook 'ktg-emacs-lisp-mode-hook)
