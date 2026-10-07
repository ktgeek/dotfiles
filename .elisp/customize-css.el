;;; -*- lexical-binding: t; -*-
(defun ktg-scss-mode-hook ()
  (setq scss-compile-at-save nil)
  (setq tab-width 2)
  (setq indent-tabs-mode nil)
  (setq show-trailing-whitespace t)
  (smartparens-mode)
  )

(add-hook 'scss-mode-hook 'ktg-scss-mode-hook)
