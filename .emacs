;;; .emacs --- Emacs init file  -*- lexical-binding: t; -*-
;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.
;; ____________________________________________________________________________
;; Fix for Native Comp (AOT) linker errors on macOS GUI launch
(let ((brew-prefix "/opt/homebrew/bin"))
  (when (file-directory-p brew-prefix)
    (setenv "PATH" (concat brew-prefix ":" (getenv "PATH")))
    (add-to-list 'exec-path brew-prefix)))

;; I should put in a conditional to see if this is a new enough
;; version of emacs that ELPA package manager exists.
(setq package-archives '(("gnu" . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

(add-to-list 'load-path (expand-file-name "~/.elisp"))
(let ((library-to-load "~/.site-lisp/load-site.el"))
  (if (file-exists-p library-to-load) (load-file library-to-load)))

;; Load most of configuration stuff AFTER emacs finishes initing
;; itself and its packages in ELPA.  (Useful on a mac where packages
;; come via that.)
(add-hook 'after-init-hook (lambda () (load "common-config")))

(global-set-key "\C-x\C-m" 'execute-extended-command)
(global-set-key "\C-c\C-m" 'execute-extended-command)

;; Lose the UI stuff
(if (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(if (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(if (fboundp 'menu-bar-mode) (menu-bar-mode -1))

; Paren mode
(show-paren-mode t)

(if (eq window-system 'ns)
  (load "customize-macemacs"))

;; This starts up emacs client if we're in a graphical environment. I
;; want the files to open up in the same frame, rather than opening
;; a new frame per emacsclient invocation.
;;
;; I've also added some size and color fun.  Why 122 spaces? Gutters
(cond (window-system
       (progn
         (add-to-list 'default-frame-alist '(width . 122))
         ;; Gonna try doing white text on black emacs for a bit
         (add-to-list 'default-frame-alist '(foreground-color . "#dcdcdc"))
         (add-to-list 'default-frame-alist '(background-color . "black"))
         (server-start))))

(put 'downcase-region 'disabled nil)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(font-lock-verbose nil)
 '(global-font-lock-mode t nil (font-lock))
 '(package-selected-packages
   '(aggressive-indent crontab-mode csv-mode
            dash-at-point docker-compose-mode dockerfile-mode
            flycheck flycheck-aspell git-gutter js2-mode magit
            markdown-mode markdown-preview-mode
            rainbow-delimiters smartparens web-mode
            yaml-mode))
 '(require-final-newline t)
 '(speedbar-directory-unshown-regexp "^\\(CVS\\|RCS\\|SCCS\\|\\..*\\)\\'")
 '(speedbar-show-unknown-files t)
 '(tramp-auto-save-directory "~/tmp")
 '(user-mail-address "kgarner@kgarner.com"))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(rainbow-delimiters-depth-1-face ((t (:foreground "#dcdcdc"))))
 '(rainbow-delimiters-depth-2-face ((t (:foreground "Red"))))
 '(rainbow-delimiters-depth-3-face ((t (:foreground "#00b000"))))
 '(rainbow-delimiters-depth-4-face ((t (:foreground "Orange"))))
 '(rainbow-delimiters-depth-5-face ((t (:foreground "Purple"))))
 '(rainbow-delimiters-depth-6-face ((t (:foreground "#d7d30d")))))

(message "Finished .emacs")
