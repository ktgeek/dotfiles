;;; -*- lexical-binding: t; -*-
;;; Disable command-q and command-w
(define-key global-map (kbd "s-q") nil)
(define-key global-map (kbd "s-w") nil)
(recentf-mode 0)

;;; I like to use Dash on OS X
(autoload 'dash-at-point "dash-at-point"
  "Search the word at point with Dash." t nil)
(global-set-key "\C-cd" 'dash-at-point)
(global-set-key "\C-ce" 'dash-at-point-with-docset)
