;;; -*- lexical-binding: t; -*-

;; Vanilla Emacs's auto-mode-alist already maps .xml to nxml-mode (via
;; the xml-mode alias), so only .tld needs its own entry here.
(add-to-list 'auto-mode-alist '("\\.tld\\'" . nxml-mode))

(defun ktg-nxml-mode-hook ()
  (setq indent-tabs-mode nil)
  (define-key nxml-mode-map [return] 'newline-and-indent)
  (sgml-electric-tag-pair-mode 1))

(add-hook 'nxml-mode-hook 'ktg-nxml-mode-hook)
