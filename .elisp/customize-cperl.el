;;; -*- lexical-binding: t; -*-
(defun ktg-cperl-mode-hook ()
  (setq cperl-font-lock t
    indent-tabs-mode nil
    cperl-extra-newline-before-brace t
    cperl-extra-newline-before-brace-multiline t)
  (cperl-set-style "C++")
  (define-key cperl-mode-map [return] 'newline-and-indent)
  )

(add-hook 'cperl-mode-hook 'ktg-cperl-mode-hook)
