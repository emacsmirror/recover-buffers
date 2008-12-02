;;; recover-buffers.el --- revisit all buffers from an auto-save file
;;
;;; Commentary:
;;
;; Works like `recover-session', but attempts to really recover all state
;; back to the way it was when Emacs quit or crashed.  Concretely, it
;; revisits all buffers which were open, however skipping any which match
;; an ignore list.
;;
;; (autoload 'recover-buffers "recover-buffers" nil t)
;;
;; As this is a fairly minor extension of existing built-in functionality,
;; no separate customization group is created.  The user-settable variables
;; all have the prefix `recover-buffers-'.
;;
;;
;; License: dual GPL v2 / BSD without advertising clause
;;
;; Author: era eriksson <http://www.iki.fi/era>
;;
;;
;;; History:
;;
;; era Thu Nov 27 15:38:06 2008 -- first public version
;;      Reimplemented from scratch, vaguely based on an earlier private version
;;
;; See the version control logs for detailed history.
;;
;;;;;;;; TODO: public darcs (or SVN?) repo

;;; Code:

(defcustom recover-buffers-skip-list nil ; '("\\`/tmp/")
  "List of regular expressions of file names to ignore in `recover-buffers'."
  :type '(repeat regexp)
  :group 'auto-save
  :group 'find-file
  :group 'backup)

(defcustom recover-buffers-verbosity-level 1
  "How much to emit progress messages during `recover-buffers-finish'.
This is a numeric level from 0 to 5; 0 means no messages."
  :type  '(integer) ;;;;;;;; TODO: number in range 0 thru 5
  :group 'auto-save
  :group 'find-file
  :group 'backup)


(defsubst recover-buffers-say (lvl &rest msg)
  (and (<= lvl recover-buffers-verbosity-level) (apply #'message msg)) )

(defun recover-buffers ()
  "Like `recover-session', but visit all the buffers from the selected file.

Files whose names match `recover-buffers-skip-list' will not be visited."
  (interactive)
  (recover-session)
  (define-key (current-local-map) "\C-c\C-c" #'recover-buffers-finish) )

(defun recover-buffers-finish ()
  "Revisit all buffers from the selected Emacs auto-save file.
Offer to recover any files for which auto-save data is available.

Invoked from `recover-buffers' through binding to C-c C-c."
  (interactive)
  ;;;;;;;; TODO: refactor `recover-session-finish', avoid duplicate code here
  (let ((file (dired-get-filename))
	(buffer (get-buffer-create " *recover-buffers*"))
	(ignored (and recover-buffers-skip-list
		      (mapconcat #'identity recover-buffers-skip-list "\\|")))
	files)

    ;; Recover any files with actual auto-save data before proceeding
    ;;;;;;;; FIXME: abort if not in a dired buffer, etc
    (recover-buffers-say 5 "Running recover-session-finish")
    (recover-session-finish)
    (recover-buffers-say 5 "Completed recover-session-finish")

    ;; Read the auto-save-list file.
    (set-buffer buffer)
    (erase-buffer)
    (insert-file-contents file)

    ;; Get the names of the files to visit into the list `files'
    (while (not (eobp))
      (let ((filename (buffer-substring-no-properties
		       (point) (line-end-position) )) )
	(if (and ignored (string-match ignored filename))
	    (recover-buffers-say
	     4 "File '%s' matches recover-buffers-skip-list; ignoring" filename)
	  (if (file-exists-p filename)
	      (progn
		(recover-buffers-say 5 "Adding file '%s' to list" filename)
		(setq files (cons filename files)) )
	    (recover-buffers-say
	     1 "File '%s' does not exist; skipping" filename) ) )
	(forward-line 2) ) )

    (recover-buffers-say 5 "Found %i file names to visit" (length files))
    (kill-buffer buffer)

    ;; Message area will likely contain a message from `recover-session'
    ;; (typically "No files can be recovered from this session now")
    ;; which will only be overwritten if there are actually files to visit.
    ;; If there are no files, we want to issue a more specific message.
    (if (not files)
	(message "No buffers recovered")

      ;;;;;;;; TODO: don't re-find recovered files (?)
      ;;;;;;;; TODO: files requiring a password to be input should be done first
      ;; (concretely, Tramp and ange-ftp files, one for each remote domain)

      ;; Conveniently, the files are in reverse order.
      ;; Visiting them in this order ends up with the first (topmost) file
      ;; visited last, i.e. in the topmost buffer again.
      (mapc #'find-file files) ) ) )

;;;;;;;; TODO: recover kill ring history etc (should hook in `desktop-read'?)

;;;;;;;; FIXME: test suite


(provide 'recover-buffers)


;;; recover-buffers.el ends here