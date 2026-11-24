;;; -*- lexical-binding: t; -*-
(defun ktg-ruby-mode-hook ()
  (setq indent-tabs-mode nil
        ruby-insert-encoding-magic-comment nil
        show-trailing-whitespace t
        ruby-deep-indent-paren nil
        ruby-deep-arglist nil
        ruby-align-to-stmt-keywords t)
  (smartparens-mode)

  ;; I should expand this to say if you can find a gemfile and a
  ;; rubocop and stuff
  (setq-local flycheck-command-wrapper-function
              (lambda (command)
                (append '("bundle" "exec") command)))
  (flycheck-mode)
  )

(add-hook 'ruby-mode-hook 'ktg-ruby-mode-hook)
(add-hook 'ruby-mode-hook #'aggressive-indent-mode)

(add-to-list 'auto-mode-alist '("\\`\\.irbrc\\'" . ruby-mode))
(add-to-list 'auto-mode-alist '("\\.yml\\'" . yaml-mode))
