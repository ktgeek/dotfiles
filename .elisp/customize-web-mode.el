;;; -*- lexical-binding: t; -*-
(defun ktg-web-mode-hook ()
  (setq indent-tabs-mode nil)
  (setq web-mode-code-indent-offset 2)
  (setq web-mode-markup-indent-offset 2)
  (setq web-mode-css-indent-offset 2))
(add-hook 'web-mode-hook 'ktg-web-mode-hook)

(add-to-list 'auto-mode-alist '("\\.rhtml\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.html\\.erb\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.thtml\\'" . html-mode))
(add-to-list 'auto-mode-alist '("\\.jsp\\'" . html-mode))
