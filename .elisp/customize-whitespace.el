;;; -*- lexical-binding: t; -*-
(require 'whitespace)
(setq whitespace-line-column 120) ;; limit line length
(setq whitespace-style '(face lines-tail trailing newline))

(add-hook 'prog-mode-hook 'whitespace-mode)
