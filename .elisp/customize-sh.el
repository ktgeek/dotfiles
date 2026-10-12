;;; -*- lexical-binding: t; -*-
(defun ktg-sh-mode-hook ()
  (setq sh-indentation 2)
  (setq indent-tabs-mode nil)
  (setq show-trailing-whitespace t)
  (smartparens-mode)
  )

(add-hook 'sh-mode-hook 'ktg-sh-mode-hook)
