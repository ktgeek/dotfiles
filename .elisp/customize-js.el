;;; -*- lexical-binding: t; -*-

;;; js2 mode is where most of our javascripts happen
(defun ktg-js2-mode-hook ()
  (setq js2-basic-offset 2)
  (setq js2-highlight-level 3)
  (setq js2-missing-semi-one-line-override t)
  (setq js2-strict-missing-semi-warning nil)
  (setq indent-tabs-mode nil)
  (setq show-trailing-whitespace t)
  (smartparens-mode)
  (rainbow-delimiters-mode)
  (flycheck-mode)
  )

(setq auto-mode-alist
      (append
       (list '("\\.js\\'" . js2-mode)
             '("\\.jsx\\'" . js2-jsx-mode)
             )
       auto-mode-alist))
(add-hook 'js2-mode-hook 'ktg-js2-mode-hook)

;;; interpreter-mode-alist maps node/nodejs shebangs to the built-in
;;; js-mode, which would skip ktg-js2-mode-hook entirely; remap it so
;;; a shebang'd script with no .js extension still gets js2-mode.
(add-to-list 'major-mode-remap-alist '(js-mode . js2-mode))

;; use local eslint from node_modules before global
;; http://emacs.stackexchange.com/questions/21205/flycheck-with-file-relative-eslint-executable
(defun ktg-use-eslint-from-node-modules ()
  (let* ((root (locate-dominating-file
                (or (buffer-file-name) default-directory)
                "node_modules"))
         (eslint (and root
                      (expand-file-name "node_modules/eslint/bin/eslint.js"
                                        root))))
    (when (and eslint (file-executable-p eslint))
      (setq-local flycheck-javascript-eslint-executable eslint))))
(add-hook 'flycheck-mode-hook #'ktg-use-eslint-from-node-modules)
