(require 'org-install)

(setq make-backup-files nil
      org-export-author-info nil
      org-export-headline-levels 3
      org-export-with-toc nil
      org-export-with-section-numbers nil
      org-export-with-LaTeX-fragments t
      org-export-html-auto-postamble nil
      org-export-html-style-include-default nil
      org-export-html-style "<link rel=\"stylesheet\" type=\"text/css\" href=\"/static/org/org-info.css\" />"
      org-export-html-use-infojs t
      org-infojs-options '((path . "http://orgmode.org/org-info.js")
                           (view . "info")
                           (toc . :table-of-contents)
                           (ltoc . "1")
                           (ftoc . "0")
                           (tdepth . "max")
                           (sdepth . "max")
                           (mouse . "underline")
                           (buttons . "0")
                           (up . :link-up)
                           (home . :link-home))
      org-babel-default-header-args '((:session . "none")
                                      (:results . "replace")
                                      (:exports . "code")
                                      (:cache . "yes")
                                      (:noweb . "no")
                                      (:hlines . "no")
                                      (:tangle . "no"))
      org-babel-load-languages '((emacs-lisp . nil)
                                 (dot . t)
                                 (ditaa . t)
                                 (R . t)
                                 (gnuplot . t)
                                 (python . nil)
                                 (ruby . nil)
                                 (clojure . nil)
                                 (sh . nil))
      org-ditaa-jar-path "/opt/ditaa/ditaa.jar"
      org-confirm-babel-evaluate nil)   ; Do not prompt to confirm evaluation. This may be dangerous.
                                        ; Make sure you understand the consequences of setting this
                                        ; See the docstring for details.
