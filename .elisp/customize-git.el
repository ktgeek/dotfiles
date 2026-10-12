;;; -*- lexical-binding: t; -*-
;;; git-commit-mode comes from magit these days; loading it enables
;;; global-git-commit-mode, which arranges for it on COMMIT_EDITMSG etc.
(require 'git-commit)
(add-hook 'git-commit-setup-hook #'git-commit-setup-flyspell)
(setq git-commit-summary-max-length 65)

(require 'git-gutter)
(global-git-gutter-mode t)
(custom-set-variables
 '(git-gutter:update-interval 2)
 '(git-gutter:window-width 2)
 '(git-gutter:handled-backends '(git svn)))
