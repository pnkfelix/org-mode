;;; ox-html.el --- HTML Back-End for Org Export Engine

;; Copyright (C) 2011-2013  Free Software Foundation, Inc.

;; Author: Jambunathan K <kjambunathan at gmail dot com>
;; Keywords: outlines, hypermedia, calendar, wp

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This library implements a HTML back-end for Org generic exporter.

;; To test it, run:
;;
;;   M-x org-export-as-html
;;
;; in an Org mode buffer.  See ox.el for more details on how this
;; exporter works.

;;; Code:

;;; Dependencies

(require 'ox)
(require 'ox-publish)
(require 'format-spec)
(eval-when-compile (require 'cl) (require 'table))



;;; Function Declarations

(declare-function org-id-find-id-file "org-id" (id))
(declare-function htmlize-region "ext:htmlize" (beg end))
(declare-function org-pop-to-buffer-same-window
		  "org-compat" (&optional buffer-or-name norecord label))


;;; Define Back-End

(org-export-define-backend html
  ((bold . org-html-bold)
   (center-block . org-html-center-block)
   (clock . org-html-clock)
   (code . org-html-code)
   (drawer . org-html-drawer)
   (dynamic-block . org-html-dynamic-block)
   (entity . org-html-entity)
   (example-block . org-html-example-block)
   (export-block . org-html-export-block)
   (export-snippet . org-html-export-snippet)
   (fixed-width . org-html-fixed-width)
   (footnote-definition . org-html-footnote-definition)
   (footnote-reference . org-html-footnote-reference)
   (headline . org-html-headline)
   (horizontal-rule . org-html-horizontal-rule)
   (inline-src-block . org-html-inline-src-block)
   (inlinetask . org-html-inlinetask)
   (inner-template . org-html-inner-template)
   (italic . org-html-italic)
   (item . org-html-item)
   (keyword . org-html-keyword)
   (latex-environment . org-html-latex-environment)
   (latex-fragment . org-html-latex-fragment)
   (line-break . org-html-line-break)
   (link . org-html-link)
   (paragraph . org-html-paragraph)
   (plain-list . org-html-plain-list)
   (plain-text . org-html-plain-text)
   (planning . org-html-planning)
   (property-drawer . org-html-property-drawer)
   (quote-block . org-html-quote-block)
   (quote-section . org-html-quote-section)
   (radio-target . org-html-radio-target)
   (section . org-html-section)
   (special-block . org-html-special-block)
   (src-block . org-html-src-block)
   (statistics-cookie . org-html-statistics-cookie)
   (strike-through . org-html-strike-through)
   (subscript . org-html-subscript)
   (superscript . org-html-superscript)
   (table . org-html-table)
   (table-cell . org-html-table-cell)
   (table-row . org-html-table-row)
   (target . org-html-target)
   (template . org-html-template)
   (timestamp . org-html-timestamp)
   (underline . org-html-underline)
   (verbatim . org-html-verbatim)
   (verse-block . org-html-verse-block))
  :export-block "HTML"
  :filters-alist ((:filter-final-output . org-html-final-function))
  :menu-entry
  (?h "Export to HTML"
      ((?H "As HTML buffer" org-html-export-as-html)
       (?h "As HTML file" org-html-export-to-html)
       (?o "As HTML file and open"
	   (lambda (a s v b)
	     (if a (org-html-export-to-html t s v b)
	       (org-open-file (org-html-export-to-html nil s v b)))))))
  :options-alist
  ((:html-extension nil nil org-html-extension)
   (:html-link-home "HTML_LINK_HOME" nil org-html-link-home)
   (:html-link-up "HTML_LINK_UP" nil org-html-link-up)
   (:html-mathjax "HTML_MATHJAX" nil "" space)
   (:html-postamble nil "html-postamble" org-html-postamble)
   (:html-preamble nil "html-preamble" org-html-preamble)
   (:html-style nil nil org-html-style)
   (:html-style-extra "HTML_STYLE" nil org-html-style-extra newline)
   (:html-style-include-default nil nil org-html-style-include-default)
   (:html-style-include-scripts nil nil org-html-style-include-scripts)
   (:html-table-tag nil nil org-html-table-tag)
   ;; Redefine regular options.
   (:creator "CREATOR" nil org-html-creator-string)
   (:with-latex nil "tex" org-html-with-latex)
   ;; Leave room for "ox-infojs.el" extension.
   (:infojs-opt "INFOJS_OPT" nil nil)))



;;; Internal Variables

(defvar org-html-format-table-no-css)
(defvar htmlize-buffer-places)  ; from htmlize.el

(defconst org-html-special-string-regexps
  '(("\\\\-" . "&shy;")
    ("---\\([^-]\\)" . "&mdash;\\1")
    ("--\\([^-]\\)" . "&ndash;\\1")
    ("\\.\\.\\." . "&hellip;"))
  "Regular expressions for special string conversion.")

(defconst org-html-scripts
  "<script type=\"text/javascript\">
/*
@licstart  The following is the entire license notice for the
JavaScript code in this tag.

Copyright (C) 2012  Free Software Foundation, Inc.

The JavaScript code in this tag is free software: you can
redistribute it and/or modify it under the terms of the GNU
General Public License (GNU GPL) as published by the Free Software
Foundation, either version 3 of the License, or (at your option)
any later version.  The code is distributed WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU GPL for more details.

As additional permission under GNU GPL version 3 section 7, you
may distribute non-source (e.g., minimized or compacted) forms of
that code without the copy of the GNU GPL normally required by
section 4, provided you include this license notice and a URL
through which recipients can access the Corresponding Source.


@licend  The above is the entire license notice
for the JavaScript code in this tag.
*/
<!--/*--><![CDATA[/*><!--*/
 function CodeHighlightOn(elem, id)
 {
   var target = document.getElementById(id);
   if(null != target) {
     elem.cacheClassElem = elem.className;
     elem.cacheClassTarget = target.className;
     target.className = \"code-highlighted\";
     elem.className   = \"code-highlighted\";
   }
 }
 function CodeHighlightOff(elem, id)
 {
   var target = document.getElementById(id);
   if(elem.cacheClassElem)
     elem.className = elem.cacheClassElem;
   if(elem.cacheClassTarget)
     target.className = elem.cacheClassTarget;
 }
/*]]>*///-->
</script>"
  "Basic JavaScript that is needed by HTML files produced by Org mode.")

(defconst org-html-style-default
  "<style type=\"text/css\">
 <!--/*--><![CDATA[/*><!--*/
  html { font-family: Times, serif; font-size: 12pt; }
  .title  { text-align: center; }
  .todo   { color: red; }
  .done   { color: green; }
  .tag    { background-color: #add8e6; font-weight:normal }
  .target { }
  .timestamp { color: #bebebe; }
  .timestamp-kwd { color: #5f9ea0; }
  .right  {margin-left:auto; margin-right:0px;  text-align:right;}
  .left   {margin-left:0px;  margin-right:auto; text-align:left;}
  .center {margin-left:auto; margin-right:auto; text-align:center;}
  p.verse { margin-left: 3% }
  pre {
	border: 1pt solid #AEBDCC;
	background-color: #F3F5F7;
	padding: 5pt;
	font-family: courier, monospace;
        font-size: 90%;
        overflow:auto;
  }
  table { border-collapse: collapse; }
  td, th { vertical-align: top;  }
  th.right  { text-align:center;  }
  th.left   { text-align:center;   }
  th.center { text-align:center; }
  td.right  { text-align:right;  }
  td.left   { text-align:left;   }
  td.center { text-align:center; }
  dt { font-weight: bold; }
  div.figure { padding: 0.5em; }
  div.figure p { text-align: center; }
  div.inlinetask {
    padding:10px;
    border:2px solid gray;
    margin:10px;
    background: #ffffcc;
  }
  textarea { overflow-x: auto; }
  .linenr { font-size:smaller }
  .code-highlighted {background-color:#ffff00;}
  .org-info-js_info-navigation { border-style:none; }
  #org-info-js_console-label { font-size:10px; font-weight:bold;
                               white-space:nowrap; }
  .org-info-js_search-highlight {background-color:#ffff00; color:#000000;
                                 font-weight:bold; }
  /*]]>*/-->
</style>"
  "The default style specification for exported HTML files.
Please use the variables `org-html-style' and
`org-html-style-extra' to add to this style.  If you wish to not
have the default style included, customize the variable
`org-html-style-include-default'.")



;;; User Configuration Variables

(defgroup org-export-html nil
  "Options for exporting Org mode files to HTML."
  :tag "Org Export HTML"
  :group 'org-export)

(defgroup org-export-htmlize nil
  "Options for processing examples with htmlize.el."
  :tag "Org Export Htmlize"
  :group 'org-export-html)


;;;; Bold etc

(defcustom org-html-text-markup-alist
  '((bold . "<b>%s</b>")
    (code . "<code>%s</code>")
    (italic . "<i>%s</i>")
    (strike-through . "<del>%s</del>")
    (underline . "<span style=\"text-decoration:underline;\">%s</span>")
    (verbatim . "<code>%s</code>"))
  "Alist of HTML expressions to convert text markup

The key must be a symbol among `bold', `code', `italic',
`strike-through', `underline' and `verbatim'.  The value is
a formatting string to wrap fontified text with.

If no association can be found for a given markup, text will be
returned as-is."
  :group 'org-export-html
  :type '(alist :key-type (symbol :tag "Markup type")
		:value-type (string :tag "Format string"))
  :options '(bold code italic strike-through underline verbatim))


;;;; Debugging

(defcustom org-html-pretty-output nil
  "Enable this to generate pretty HTML."
  :group 'org-export-html
  :type 'boolean)


;;;; Drawers

(defcustom org-html-format-drawer-function nil
  "Function called to format a drawer in HTML code.

The function must accept two parameters:
  NAME      the drawer name, like \"LOGBOOK\"
  CONTENTS  the contents of the drawer.

The function should return the string to be exported.

For example, the variable could be set to the following function
in order to mimic default behaviour:

\(defun org-html-format-drawer-default \(name contents\)
  \"Format a drawer element for HTML export.\"
  contents\)"
  :group 'org-export-html
  :type 'function)


;;;; Footnotes

(defcustom org-html-footnotes-section "<div id=\"footnotes\">
<h2 class=\"footnotes\">%s: </h2>
<div id=\"text-footnotes\">
%s
</div>
</div>"
  "Format for the footnotes section.
Should contain a two instances of %s.  The first will be replaced with the
language-specific word for \"Footnotes\", the second one will be replaced
by the footnotes themselves."
  :group 'org-export-html
  :type 'string)

(defcustom org-html-footnote-format "<sup>%s</sup>"
  "The format for the footnote reference.
%s will be replaced by the footnote reference itself."
  :group 'org-export-html
  :type 'string)

(defcustom org-html-footnote-separator "<sup>, </sup>"
  "Text used to separate footnotes."
  :group 'org-export-html
  :type 'string)


;;;; Headline

(defcustom org-html-toplevel-hlevel 2
  "The <H> level for level 1 headings in HTML export.
This is also important for the classes that will be wrapped around headlines
and outline structure.  If this variable is 1, the top-level headlines will
be <h1>, and the corresponding classes will be outline-1, section-number-1,
and outline-text-1.  If this is 2, all of these will get a 2 instead.
The default for this variable is 2, because we use <h1> for formatting the
document title."
  :group 'org-export-html
  :type 'integer)

(defcustom org-html-format-headline-function nil
  "Function to format headline text.

This function will be called with 5 arguments:
TODO      the todo keyword (string or nil).
TODO-TYPE the type of todo (symbol: `todo', `done', nil)
PRIORITY  the priority of the headline (integer or nil)
TEXT      the main headline text (string).
TAGS      the tags (string or nil).

The function result will be used in the section format string.

As an example, one could set the variable to the following, in
order to reproduce the default set-up:

\(defun org-html-format-headline \(todo todo-type priority text tags)
  \"Default format function for an headline.\"
  \(concat \(when todo
            \(format \"\\\\textbf{\\\\textsc{\\\\textsf{%s}}} \" todo))
	  \(when priority
            \(format \"\\\\framebox{\\\\#%c} \" priority))
	  text
	  \(when tags (format \"\\\\hfill{}\\\\textsc{%s}\" tags))))"
  :group 'org-export-html
  :type 'function)


;;;; HTML-specific

(defcustom org-html-allow-name-attribute-in-anchors t
  "When nil, do not set \"name\" attribute in anchors.
By default, anchors are formatted with both \"id\" and \"name\"
attributes, when appropriate."
  :group 'org-export-html
  :type 'boolean)


;;;; Inlinetasks

(defcustom org-html-format-inlinetask-function nil
  "Function called to format an inlinetask in HTML code.

The function must accept six parameters:
  TODO      the todo keyword, as a string
  TODO-TYPE the todo type, a symbol among `todo', `done' and nil.
  PRIORITY  the inlinetask priority, as a string
  NAME      the inlinetask name, as a string.
  TAGS      the inlinetask tags, as a list of strings.
  CONTENTS  the contents of the inlinetask, as a string.

The function should return the string to be exported.

For example, the variable could be set to the following function
in order to mimic default behaviour:

\(defun org-html-format-inlinetask \(todo type priority name tags contents\)
\"Format an inline task element for HTML export.\"
  \(let \(\(full-title
	 \(concat
	  \(when todo
            \(format \"\\\\textbf{\\\\textsf{\\\\textsc{%s}}} \" todo))
	  \(when priority (format \"\\\\framebox{\\\\#%c} \" priority))
	  title
	  \(when tags (format \"\\\\hfill{}\\\\textsc{%s}\" tags)))))
    \(format (concat \"\\\\begin{center}\\n\"
		    \"\\\\fbox{\\n\"
		    \"\\\\begin{minipage}[c]{.6\\\\textwidth}\\n\"
		    \"%s\\n\\n\"
		    \"\\\\rule[.8em]{\\\\textwidth}{2pt}\\n\\n\"
		    \"%s\"
		    \"\\\\end{minipage}}\"
		    \"\\\\end{center}\")
	    full-title contents))"
  :group 'org-export-html
  :type 'function)


;;;; LaTeX

(defcustom org-html-with-latex org-export-with-latex
  "Non-nil means process LaTeX math snippets.

When set, the exporter will process LaTeX environments and
fragments.

This option can also be set with the +OPTIONS line,
e.g. \"tex:mathjax\".  Allowed values are:

nil            Ignore math snippets.
`verbatim'     Keep everything in verbatim
`dvipng'       Process the LaTeX fragments to images.  This will also
               include processing of non-math environments.
`imagemagick'  Convert the LaTeX fragments to pdf files and use
               imagemagick to convert pdf files to png files.
`mathjax'      Do MathJax preprocessing and arrange for MathJax.js to
               be loaded.
t              Synonym for `mathjax'."
  :group 'org-export-html
  :type '(choice
	  (const :tag "Do not process math in any way" nil)
	  (const :tag "Use dvipng to make images" dvipng)
	  (const :tag "Use imagemagick to make images" imagemagick)
	  (const :tag "Use MathJax to display math" mathjax)
	  (const :tag "Leave math verbatim" verbatim)))


;;;; Links :: Generic

(defcustom org-html-link-org-files-as-html t
  "Non-nil means make file links to `file.org' point to `file.html'.
When org-mode is exporting an org-mode file to HTML, links to
non-html files are directly put into a href tag in HTML.
However, links to other Org-mode files (recognized by the
extension `.org.) should become links to the corresponding html
file, assuming that the linked org-mode file will also be
converted to HTML.
When nil, the links still point to the plain `.org' file."
  :group 'org-export-html
  :type 'boolean)


;;;; Links :: Inline images

(defcustom org-html-inline-images 'maybe
  "Non-nil means inline images into exported HTML pages.
This is done using an <img> tag.  When nil, an anchor with href is used to
link to the image.  If this option is `maybe', then images in links with
an empty description will be inlined, while images with a description will
be linked only."
  :group 'org-export-html
  :type '(choice (const :tag "Never" nil)
		 (const :tag "Always" t)
		 (const :tag "When there is no description" maybe)))

(defcustom org-html-inline-image-rules
  '(("file" . "\\.\\(jpeg\\|jpg\\|png\\|gif\\|svg\\)\\'")
    ("http" . "\\.\\(jpeg\\|jpg\\|png\\|gif\\|svg\\)\\'")
    ("https" . "\\.\\(jpeg\\|jpg\\|png\\|gif\\|svg\\)\\'"))
  "Rules characterizing image files that can be inlined into HTML.

A rule consists in an association whose key is the type of link
to consider, and value is a regexp that will be matched against
link's path.

Note that, by default, the image extension *actually* allowed
depend on the way the HTML file is processed.  When used with
pdflatex, pdf, jpg and png images are OK.  When processing
through dvi to Postscript, only ps and eps are allowed.  The
default we use here encompasses both."
  :group 'org-export-html
  :type '(alist :key-type (string :tag "Type")
		:value-type (regexp :tag "Path")))


;;;; Plain Text

(defcustom org-html-protect-char-alist
  '(("&" . "&amp;")
    ("<" . "&lt;")
    (">" . "&gt;"))
  "Alist of characters to be converted by `org-html-protect'."
  :group 'org-export-html
  :type '(repeat (cons (string :tag "Character")
		       (string :tag "HTML equivalent"))))


;;;; Src Block

(defcustom org-export-htmlize-output-type 'inline-css
  "Output type to be used by htmlize when formatting code snippets.
Choices are `css', to export the CSS selectors only, or `inline-css', to
export the CSS attribute values inline in the HTML.  We use as default
`inline-css', in order to make the resulting HTML self-containing.

However, this will fail when using Emacs in batch mode for export, because
then no rich font definitions are in place.  It will also not be good if
people with different Emacs setup contribute HTML files to a website,
because the fonts will represent the individual setups.  In these cases,
it is much better to let Org/Htmlize assign classes only, and to use
a style file to define the look of these classes.
To get a start for your css file, start Emacs session and make sure that
all the faces you are interested in are defined, for example by loading files
in all modes you want.  Then, use the command
\\[org-export-htmlize-generate-css] to extract class definitions."
  :group 'org-export-htmlize
  :type '(choice (const css) (const inline-css)))

(defcustom org-export-htmlize-font-prefix "org-"
  "The prefix for CSS class names for htmlize font specifications."
  :group 'org-export-htmlize
  :type 'string)

(defcustom org-export-htmlized-org-css-url nil
  "URL pointing to a CSS file defining text colors for htmlized Emacs buffers.
Normally when creating an htmlized version of an Org buffer, htmlize will
create CSS to define the font colors.  However, this does not work when
converting in batch mode, and it also can look bad if different people
with different fontification setup work on the same website.
When this variable is non-nil, creating an htmlized version of an Org buffer
using `org-export-as-org' will remove the internal CSS section and replace it
with a link to this URL."
  :group 'org-export-htmlize
  :type '(choice
	  (const :tag "Keep internal css" nil)
	  (string :tag "URL or local href")))


;;;; Table

(defcustom org-html-table-tag
  "<table border=\"2\" cellspacing=\"0\" cellpadding=\"6\" rules=\"groups\" frame=\"hsides\">"
  "The HTML tag that is used to start a table.
This must be a <table> tag, but you may change the options like
borders and spacing."
  :group 'org-export-html
  :type 'string)

(defcustom org-html-table-header-tags '("<th scope=\"%s\"%s>" . "</th>")
  "The opening tag for table header fields.
This is customizable so that alignment options can be specified.
The first %s will be filled with the scope of the field, either row or col.
The second %s will be replaced by a style entry to align the field.
See also the variable `org-html-table-use-header-tags-for-first-column'.
See also the variable `org-html-table-align-individual-fields'."
  :group 'org-export-tables		; FIXME: change group?
  :type '(cons (string :tag "Opening tag") (string :tag "Closing tag")))

(defcustom org-html-table-data-tags '("<td%s>" . "</td>")
  "The opening tag for table data fields.
This is customizable so that alignment options can be specified.
The first %s will be filled with the scope of the field, either row or col.
The second %s will be replaced by a style entry to align the field.
See also the variable `org-html-table-align-individual-fields'."
  :group 'org-export-tables
  :type '(cons (string :tag "Opening tag") (string :tag "Closing tag")))

(defcustom org-html-table-row-tags '("<tr>" . "</tr>")
  "The opening tag for table data fields.
This is customizable so that alignment options can be specified.
Instead of strings, these can be Lisp forms that will be evaluated
for each row in order to construct the table row tags.  During evaluation,
the variable `head' will be true when this is a header line, nil when this
is a body line.  And the variable `nline' will contain the line number,
starting from 1 in the first header line.  For example

  (setq org-html-table-row-tags
        (cons '(if head
                   \"<tr>\"
                 (if (= (mod nline 2) 1)
                     \"<tr class=\\\"tr-odd\\\">\"
                   \"<tr class=\\\"tr-even\\\">\"))
              \"</tr>\"))

will give even lines the class \"tr-even\" and odd lines the class \"tr-odd\"."
  :group 'org-export-tables
  :type '(cons
	  (choice :tag "Opening tag"
		  (string :tag "Specify")
		  (sexp))
	  (choice :tag "Closing tag"
		  (string :tag "Specify")
		  (sexp))))

(defcustom org-html-table-align-individual-fields t
  "Non-nil means attach style attributes for alignment to each table field.
When nil, alignment will only be specified in the column tags, but this
is ignored by some browsers (like Firefox, Safari).  Opera does it right
though."
  :group 'org-export-tables
  :type 'boolean)

(defcustom org-html-table-use-header-tags-for-first-column nil
  "Non-nil means format column one in tables with header tags.
When nil, also column one will use data tags."
  :group 'org-export-tables
  :type 'boolean)

(defcustom org-html-table-caption-above t
  "When non-nil, place caption string at the beginning of the table.
Otherwise, place it near the end."
  :group 'org-export-html
  :type 'boolean)


;;;; Tags

(defcustom org-html-tag-class-prefix ""
  "Prefix to class names for TODO keywords.
Each tag gets a class given by the tag itself, with this prefix.
The default prefix is empty because it is nice to just use the keyword
as a class name.  But if you get into conflicts with other, existing
CSS classes, then this prefix can be very useful."
  :group 'org-export-html
  :type 'string)


;;;; Template :: Generic

(defcustom org-html-extension "html"
  "The extension for exported HTML files."
  :group 'org-export-html
  :type 'string)

(defcustom org-html-xml-declaration
  '(("html" . "<?xml version=\"1.0\" encoding=\"%s\"?>")
    ("php" . "<?php echo \"<?xml version=\\\"1.0\\\" encoding=\\\"%s\\\" ?>\"; ?>"))
  "The extension for exported HTML files.
%s will be replaced with the charset of the exported file.
This may be a string, or an alist with export extensions
and corresponding declarations."
  :group 'org-export-html
  :type '(choice
	  (string :tag "Single declaration")
	  (repeat :tag "Dependent on extension"
		  (cons (string :tag "Extension")
			(string :tag "Declaration")))))

(defcustom org-html-coding-system 'utf-8
  "Coding system for HTML export.
Use utf-8 as the default value."
  :group 'org-export-html
  :type 'coding-system)

(defcustom org-html-divs '("preamble" "content" "postamble")
  "The name of the main divs for HTML export.
This is a list of three strings, the first one for the preamble
DIV, the second one for the content DIV and the third one for the
postamble DIV."
  :group 'org-export-html
  :type '(list
	  (string :tag " Div for the preamble:")
	  (string :tag "  Div for the content:")
	  (string :tag "Div for the postamble:")))


;;;; Template :: Mathjax

(defcustom org-html-mathjax-options
  '((path  "http://orgmode.org/mathjax/MathJax.js")
    (scale "100")
    (align "center")
    (indent "2em")
    (mathml nil))
  "Options for MathJax setup.

path        The path where to find MathJax
scale       Scaling for the HTML-CSS backend, usually between 100 and 133
align       How to align display math: left, center, or right
indent      If align is not center, how far from the left/right side?
mathml      Should a MathML player be used if available?
            This is faster and reduces bandwidth use, but currently
            sometimes has lower spacing quality.  Therefore, the default is
            nil.  When browsers get better, this switch can be flipped.

You can also customize this for each buffer, using something like

#+MATHJAX: scale:\"133\" align:\"right\" mathml:t path:\"/MathJax/\""
  :group 'org-export-html
  :type '(list :greedy t
	      (list :tag "path   (the path from where to load MathJax.js)"
		    (const :format "       " path) (string))
	      (list :tag "scale  (scaling for the displayed math)"
		    (const :format "       " scale) (string))
	      (list :tag "align  (alignment of displayed equations)"
		    (const :format "       " align) (string))
	      (list :tag "indent (indentation with left or right alignment)"
		    (const :format "       " indent) (string))
	      (list :tag "mathml (should MathML display be used is possible)"
		    (const :format "       " mathml) (boolean))))

(defcustom org-html-mathjax-template
  "<script type=\"text/javascript\" src=\"%PATH\">
<!--/*--><![CDATA[/*><!--*/
    MathJax.Hub.Config({
        // Only one of the two following lines, depending on user settings
        // First allows browser-native MathML display, second forces HTML/CSS
        :MMLYES: config: [\"MMLorHTML.js\"], jax: [\"input/TeX\"],
        :MMLNO: jax: [\"input/TeX\", \"output/HTML-CSS\"],
        extensions: [\"tex2jax.js\",\"TeX/AMSmath.js\",\"TeX/AMSsymbols.js\",
                     \"TeX/noUndefined.js\"],
        tex2jax: {
            inlineMath: [ [\"\\\\(\",\"\\\\)\"] ],
            displayMath: [ ['$$','$$'], [\"\\\\[\",\"\\\\]\"], [\"\\\\begin{displaymath}\",\"\\\\end{displaymath}\"] ],
            skipTags: [\"script\",\"noscript\",\"style\",\"textarea\",\"pre\",\"code\"],
            ignoreClass: \"tex2jax_ignore\",
            processEscapes: false,
            processEnvironments: true,
            preview: \"TeX\"
        },
        showProcessingMessages: true,
        displayAlign: \"%ALIGN\",
        displayIndent: \"%INDENT\",

        \"HTML-CSS\": {
             scale: %SCALE,
             availableFonts: [\"STIX\",\"TeX\"],
             preferredFont: \"TeX\",
             webFont: \"TeX\",
             imageFont: \"TeX\",
             showMathMenu: true,
        },
        MMLorHTML: {
             prefer: {
                 MSIE:    \"MML\",
                 Firefox: \"MML\",
                 Opera:   \"HTML\",
                 other:   \"HTML\"
             }
        }
    });
/*]]>*///-->
</script>"
  "The MathJax setup for XHTML files."
  :group 'org-export-html
  :type 'string)


;;;; Template :: Postamble

(defcustom org-html-postamble 'auto
  "Non-nil means insert a postamble in HTML export.

When `t', insert a string as defined by the formatting string in
`org-html-postamble-format'.  When set to a string, this
string overrides `org-html-postamble-format'.  When set to
'auto, discard `org-html-postamble-format' and honor
`org-export-author/email/creator-info' variables.  When set to a
function, apply this function and insert the returned string.
The function takes the property list of export options as its
only argument.

Setting :html-postamble in publishing projects will take
precedence over this variable."
  :group 'org-export-html
  :type '(choice (const :tag "No postamble" nil)
		 (const :tag "Auto preamble" 'auto)
		 (const :tag "Default formatting string" t)
		 (string :tag "Custom formatting string")
		 (function :tag "Function (must return a string)")))

(defcustom org-html-postamble-format
  '(("en" "<p class=\"author\">Author: %a (%e)</p>
<p class=\"date\">Date: %d</p>
<p class=\"creator\">Generated by %c</p>
<p class=\"xhtml-validation\">%v</p>"))
  "Alist of languages and format strings for the HTML postamble.

The first element of each list is the language code, as used for
the #+LANGUAGE keyword.

The second element of each list is a format string to format the
postamble itself.  This format string can contain these elements:

  %a stands for the author's name.
  %e stands for the author's email.
  %d stands for the date.
  %c will be replaced by information about Org/Emacs versions.
  %v will be replaced by `org-html-validation-link'.

If you need to use a \"%\" character, you need to escape it
like that: \"%%\"."
  :group 'org-export-html
  :type '(alist :key-type (string :tag "Language")
		:value-type (string :tag "Format string")))

(defcustom org-html-validation-link
  "<a href=\"http://validator.w3.org/check?uri=referer\">Validate XHTML 1.0</a>"
  "Link to HTML validation service."
  :group 'org-export-html
  :type 'string)

(defcustom org-html-creator-string
  (format "Generated by <a href=\"http://orgmode.org\">Org</a> mode %s in <a href=\"http://www.gnu.org/software/emacs/\">Emacs</a> %s."
	  (if (fboundp 'org-version) (org-version) "(Unknown)")
	  emacs-version)
  "String to insert at the end of the HTML document."
  :group 'org-export-html
  :type '(string :tag "Creator string"))


;;;; Template :: Preamble

(defcustom org-html-preamble t
  "Non-nil means insert a preamble in HTML export.

When `t', insert a string as defined by one of the formatting
strings in `org-html-preamble-format'.  When set to a
string, this string overrides `org-html-preamble-format'.
When set to a function, apply this function and insert the
returned string.  The function takes the property list of export
options as its only argument.

Setting :html-preamble in publishing projects will take
precedence over this variable."
  :group 'org-export-html
  :type '(choice (const :tag "No preamble" nil)
		 (const :tag "Default preamble" t)
		 (string :tag "Custom formatting string")
		 (function :tag "Function (must return a string)")))

(defcustom org-html-preamble-format '(("en" ""))
  "Alist of languages and format strings for the HTML preamble.

The first element of each list is the language code, as used for
the #+LANGUAGE keyword.

The second element of each list is a format string to format the
preamble itself.  This format string can contain these elements:

  %t stands for the title.
  %a stands for the author's name.
  %e stands for the author's email.
  %d stands for the date.

If you need to use a \"%\" character, you need to escape it
like that: \"%%\"."
  :group 'org-export-html
  :type '(alist :key-type (string :tag "Language")
		:value-type (string :tag "Format string")))

(defcustom org-html-link-up ""
  "Where should the \"UP\" link of exported HTML pages lead?"
  :group 'org-export-html
  :type '(string :tag "File or URL"))

(defcustom org-html-link-home ""
  "Where should the \"HOME\" link of exported HTML pages lead?"
  :group 'org-export-html
  :type '(string :tag "File or URL"))

(defcustom org-html-home/up-format
  "<div id=\"org-div-home-and-up\" style=\"text-align:right;font-size:70%%;white-space:nowrap;\">
 <a accesskey=\"h\" href=\"%s\"> UP </a>
 |
 <a accesskey=\"H\" href=\"%s\"> HOME </a>
</div>"
  "Snippet used to insert the HOME and UP links.
This is a format string, the first %s will receive the UP link,
the second the HOME link.  If both `org-html-link-up' and
`org-html-link-home' are empty, the entire snippet will be
ignored."
  :group 'org-export-html
  :type 'string)


;;;; Template :: Scripts

(defcustom org-html-style-include-scripts t
  "Non-nil means include the JavaScript snippets in exported HTML files.
The actual script is defined in `org-html-scripts' and should
not be modified."
  :group 'org-export-html
  :type 'boolean)


;;;; Template :: Styles

(defcustom org-html-style-include-default t
  "Non-nil means include the default style in exported HTML files.
The actual style is defined in `org-html-style-default' and should
not be modified.  Use the variables `org-html-style' to add
your own style information."
  :group 'org-export-html
  :type 'boolean)
;;;###autoload
(put 'org-html-style-include-default 'safe-local-variable 'booleanp)

(defcustom org-html-style ""
  "Org-wide style definitions for exported HTML files.

This variable needs to contain the full HTML structure to provide a style,
including the surrounding HTML tags.  If you set the value of this variable,
you should consider to include definitions for the following classes:
 title, todo, done, timestamp, timestamp-kwd, tag, target.

For example, a valid value would be:

   <style type=\"text/css\">
    <![CDATA[
       p { font-weight: normal; color: gray; }
       h1 { color: black; }
      .title { text-align: center; }
      .todo, .timestamp-kwd { color: red; }
      .done { color: green; }
    ]]>
   </style>

If you'd like to refer to an external style file, use something like

   <link rel=\"stylesheet\" type=\"text/css\" href=\"mystyles.css\">

As the value of this option simply gets inserted into the HTML <head> header,
you can \"misuse\" it to add arbitrary text to the header.
See also the variable `org-html-style-extra'."
  :group 'org-export-html
  :type 'string)
;;;###autoload
(put 'org-html-style 'safe-local-variable 'stringp)

(defcustom org-html-style-extra ""
  "Additional style information for HTML export.
The value of this variable is inserted into the HTML buffer right after
the value of `org-html-style'.  Use this variable for per-file
settings of style information, and do not forget to surround the style
settings with <style>...</style> tags."
  :group 'org-export-html
  :type 'string)
;;;###autoload
(put 'org-html-style-extra 'safe-local-variable 'stringp)


;;;; Todos

(defcustom org-html-todo-kwd-class-prefix ""
  "Prefix to class names for TODO keywords.
Each TODO keyword gets a class given by the keyword itself, with this prefix.
The default prefix is empty because it is nice to just use the keyword
as a class name.  But if you get into conflicts with other, existing
CSS classes, then this prefix can be very useful."
  :group 'org-export-html
  :type 'string)

(defcustom org-html-display-buffer-mode 'html-mode
  "Default mode when visiting the HTML output."
  :group 'org-export-html
  :version "24.3"
  :type '(choice (function 'html-mode)
		 (function 'nxml-mode)
		 (function :tag "Other mode")))



;;; Internal Functions

(defun org-html-format-inline-image (src &optional
					   caption label attr standalone-p)
  (let* ((id (if (not label) ""
	       (format " id=\"%s\"" (org-export-solidify-link-text label))))
	 (attr (concat attr
		       (cond
			((string-match "\\<alt=" (or attr "")) "")
			((string-match "^ltxpng/" src)
			 (format " alt=\"%s\""
				 (org-html-encode-plain-text
				  (org-find-text-property-in-string
				   'org-latex-src src))))
			(t (format " alt=\"%s\""
				   (file-name-nondirectory src)))))))
    (cond
     (standalone-p
      (let ((img (format "<img src=\"%s\" %s/>" src attr)))
	(format "\n<div%s class=\"figure\">%s%s\n</div>"
		id (format "\n<p>%s</p>" img)
		(when caption (format "\n<p>%s</p>" caption)))))
     (t (format "<img src=\"%s\" %s/>" src (concat attr id))))))

(defun org-html--textarea-block (element)
  "Transcode ELEMENT into a textarea block.
ELEMENT is either a src block or an example block."
  (let ((code (car (org-export-unravel-code element)))
	(attr (org-export-read-attribute :attr_html element)))
    (format "<p>\n<textarea cols=\"%d\" rows=\"%d\">\n%s</textarea>\n</p>"
	    (or (plist-get attr :width) 80)
	    (or (plist-get attr :height) (org-count-lines code))
	    code)))


;;;; Bibliography

(defun org-html-bibliography ()
  "Find bibliography, cut it out and return it."
  (catch 'exit
    (let (beg end (cnt 1) bib)
      (save-excursion
	(goto-char (point-min))
	(when (re-search-forward
	       "^[ \t]*<div \\(id\\|class\\)=\"bibliography\"" nil t)
	  (setq beg (match-beginning 0))
	  (while (re-search-forward "</?div\\>" nil t)
	    (setq cnt (+ cnt (if (string= (match-string 0) "<div") +1 -1)))
	    (when (= cnt 0)
	      (and (looking-at ">") (forward-char 1))
	      (setq bib (buffer-substring beg (point)))
	      (delete-region beg (point))
	    (throw 'exit bib))))
	nil))))

;;;; Table

(defun org-html-splice-attributes (tag attributes)
  "Read attributes in string ATTRIBUTES, add and replace in HTML tag TAG."
  (if (not attributes)
      tag
    (let (oldatt newatt)
      (setq oldatt (org-extract-attributes-from-string tag)
	    tag (pop oldatt)
	    newatt (cdr (org-extract-attributes-from-string attributes)))
      (while newatt
	(setq oldatt (plist-put oldatt (pop newatt) (pop newatt))))
      (if (string-match ">" tag)
	  (setq tag
		(replace-match (concat (org-attributes-to-string oldatt) ">")
			       t t tag)))
      tag)))

(defun org-export-splice-style (style extra)
  "Splice EXTRA into STYLE, just before \"</style>\"."
  (if (and (stringp extra)
	   (string-match "\\S-" extra)
	   (string-match "</style>" style))
      (concat (substring style 0 (match-beginning 0))
	      "\n" extra "\n"
	      (substring style (match-beginning 0)))
    style))

(defun org-export-htmlize-region-for-paste (beg end)
  "Convert the region to HTML, using htmlize.el.
This is much like `htmlize-region-for-paste', only that it uses
the settings define in the org-... variables."
  (let* ((htmlize-output-type org-export-htmlize-output-type)
	 (htmlize-css-name-prefix org-export-htmlize-font-prefix)
	 (htmlbuf (htmlize-region beg end)))
    (unwind-protect
	(with-current-buffer htmlbuf
	  (buffer-substring (plist-get htmlize-buffer-places 'content-start)
			    (plist-get htmlize-buffer-places 'content-end)))
      (kill-buffer htmlbuf))))

;;;###autoload
(defun org-export-htmlize-generate-css ()
  "Create the CSS for all font definitions in the current Emacs session.
Use this to create face definitions in your CSS style file that can then
be used by code snippets transformed by htmlize.
This command just produces a buffer that contains class definitions for all
faces used in the current Emacs session.  You can copy and paste the ones you
need into your CSS file.

If you then set `org-export-htmlize-output-type' to `css', calls
to the function `org-export-htmlize-region-for-paste' will
produce code that uses these same face definitions."
  (interactive)
  (require 'htmlize)
  (and (get-buffer "*html*") (kill-buffer "*html*"))
  (with-temp-buffer
    (let ((fl (face-list))
	  (htmlize-css-name-prefix "org-")
	  (htmlize-output-type 'css)
	  f i)
      (while (setq f (pop fl)
		   i (and f (face-attribute f :inherit)))
	(when (and (symbolp f) (or (not i) (not (listp i))))
	  (insert (org-add-props (copy-sequence "1") nil 'face f))))
      (htmlize-region (point-min) (point-max))))
  (org-pop-to-buffer-same-window "*html*")
  (goto-char (point-min))
  (if (re-search-forward "<style" nil t)
      (delete-region (point-min) (match-beginning 0)))
  (if (re-search-forward "</style>" nil t)
      (delete-region (1+ (match-end 0)) (point-max)))
  (beginning-of-line 1)
  (if (looking-at " +") (replace-match ""))
  (goto-char (point-min)))

(defun org-html--make-string (n string)
  "Build a string by concatenating N times STRING."
  (let (out) (dotimes (i n out) (setq out (concat string out)))))

(defun org-html-toc-text (toc-entries)
  (let* ((prev-level (1- (nth 1 (car toc-entries))))
	 (start-level prev-level))
    (concat
     (mapconcat
      (lambda (entry)
	(let ((headline (nth 0 entry))
	      (level (nth 1 entry)))
	  (concat
	   (let* ((cnt (- level prev-level))
		  (times (if (> cnt 0) (1- cnt) (- cnt)))
		  rtn)
	     (setq prev-level level)
	     (concat
	      (org-html--make-string
	       times (cond ((> cnt 0) "\n<ul>\n<li>")
			   ((< cnt 0) "</li>\n</ul>\n")))
	      (if (> cnt 0) "\n<ul>\n<li>" "</li>\n<li>")))
	   headline)))
      toc-entries "")
     (org-html--make-string (- prev-level start-level) "</li>\n</ul>\n"))))

(defun* org-html-format-toc-headline
    (todo todo-type priority text tags
	  &key level section-number headline-label &allow-other-keys)
  (let ((headline (concat
		   section-number (and section-number ". ")
		   text
		   (and tags "&nbsp;&nbsp;&nbsp;") (org-html--tags tags))))
    (format "<a href=\"#%s\">%s</a>"
	    (org-export-solidify-link-text headline-label)
	    (if (not nil) headline
	      (format "<span class=\"%s\">%s</span>" todo-type headline)))))

(defun org-html-toc (depth info)
  (let* ((headlines (org-export-collect-headlines info depth))
	 (toc-entries
	  (loop for headline in headlines collect
		(list (org-html-format-headline--wrap
		       headline info 'org-html-format-toc-headline)
		      (org-export-get-relative-level headline info)))))
    (when toc-entries
      (concat
       "<div id=\"table-of-contents\">\n"
       (format "<h%d>%s</h%d>\n"
	       org-html-toplevel-hlevel
	       (org-html--translate "Table of Contents" info)
	       org-html-toplevel-hlevel)
       "<div id=\"text-table-of-contents\">"
       (org-html-toc-text toc-entries)
       "</div>\n"
       "</div>\n"))))

(defun org-html-fix-class-name (kwd) 	; audit callers of this function
  "Turn todo keyword into a valid class name.
Replaces invalid characters with \"_\"."
  (save-match-data
    (while (string-match "[^a-zA-Z0-9_]" kwd)
      (setq kwd (replace-match "_" t t kwd))))
  kwd)

(defun org-html-format-footnote-reference (n def refcnt)
  (let ((extra (if (= refcnt 1) "" (format ".%d"  refcnt))))
    (format org-html-footnote-format
	    (let* ((id (format "fnr.%s%s" n extra))
		   (href (format " href=\"#fn.%s\"" n))
		   (attributes (concat " class=\"footref\"" href)))
	      (org-html--anchor id n attributes)))))

(defun org-html-format-footnotes-section (section-name definitions)
  (if (not definitions) ""
    (format org-html-footnotes-section section-name definitions)))

(defun org-html-format-footnote-definition (fn)
  (let ((n (car fn)) (def (cdr fn)))
    (format
     "<tr>\n<td>%s</td>\n<td>%s</td>\n</tr>\n"
     (format org-html-footnote-format
	     (let* ((id (format "fn.%s" n))
		    (href (format " href=\"#fnr.%s\"" n))
		    (attributes (concat " class=\"footnum\"" href)))
	       (org-html--anchor id n attributes)))
     def)))

(defun org-html-footnote-section (info)
  (let* ((fn-alist (org-export-collect-footnote-definitions
		    (plist-get info :parse-tree) info))

	 (fn-alist
	  (loop for (n type raw) in fn-alist collect
		(cons n (if (eq (org-element-type raw) 'org-data)
			    (org-trim (org-export-data raw info))
			  (format "<p>%s</p>"
				  (org-trim (org-export-data raw info))))))))
    (when fn-alist
      (org-html-format-footnotes-section
       (org-html--translate "Footnotes" info)
       (format
	"<table>\n%s\n</table>\n"
	(mapconcat 'org-html-format-footnote-definition fn-alist "\n"))))))



;;; Template

(defun org-html--build-meta-info (info)
  "Return meta tags for exported document.
INFO is a plist used as a communication channel."
  (let* ((title (org-export-data (plist-get info :title) info))
	 (author (and (plist-get info :with-author)
		      (let ((auth (plist-get info :author)))
			(and auth (org-export-data auth info)))))
	 (date (and (plist-get info :with-date)
		    (let ((date (plist-get info :date)))
		      (and date (org-export-data date info)))))
	 (description (plist-get info :description))
	 (keywords (plist-get info :keywords)))
    (concat
     (format "<title>%s</title>\n" title)
     (format
      "<meta http-equiv=\"Content-Type\" content=\"text/html;charset=%s\"/>\n"
      (or (and org-html-coding-system
	       (fboundp 'coding-system-get)
	       (coding-system-get org-html-coding-system 'mime-charset))
	  "iso-8859-1"))
     (format "<meta name=\"title\" content=\"%s\"/>\n" title)
     (format "<meta name=\"generator\" content=\"Org-mode\"/>\n")
     (and date (format "<meta name=\"generated\" content=\"%s\"/>\n" date))
     (and author (format "<meta name=\"author\" content=\"%s\"/>\n" author))
     (and description
	  (format "<meta name=\"description\" content=\"%s\"/>\n" description))
     (and keywords
	  (format "<meta name=\"keywords\" content=\"%s\"/>\n" keywords)))))

(defun org-html--build-style (info)
  "Return style information for exported document.
INFO is a plist used as a communication channel."
  (org-element-normalize-string
   (concat
    (when (plist-get info :html-style-include-default) org-html-style-default)
    (org-element-normalize-string (plist-get info :html-style))
    (org-element-normalize-string (plist-get info :html-style-extra))
    (when (plist-get info :html-style-include-scripts) org-html-scripts))))

(defun org-html--build-mathjax-config (info)
  "Insert the user setup into the mathjax template.
INFO is a plist used as a communication channel."
  (when (and (memq (plist-get info :with-latex) '(mathjax t))
	     (org-element-map (plist-get info :parse-tree)
		 '(latex-fragment latex-environment) 'identity info t))
    (let ((template org-html-mathjax-template)
	  (options org-html-mathjax-options)
	  (in-buffer (or (plist-get info :html-mathjax) ""))
	  name val (yes "   ") (no "// ") x)
      (mapc
       (lambda (e)
	 (setq name (car e) val (nth 1 e))
	 (if (string-match (concat "\\<" (symbol-name name) ":") in-buffer)
	     (setq val (car (read-from-string
			     (substring in-buffer (match-end 0))))))
	 (if (not (stringp val)) (setq val (format "%s" val)))
	 (if (string-match (concat "%" (upcase (symbol-name name))) template)
	     (setq template (replace-match val t t template))))
       options)
      (setq val (nth 1 (assq 'mathml options)))
      (if (string-match (concat "\\<mathml:") in-buffer)
	  (setq val (car (read-from-string
			  (substring in-buffer (match-end 0))))))
      ;; Exchange prefixes depending on mathml setting.
      (if (not val) (setq x yes yes no no x))
      ;; Replace cookies to turn on or off the config/jax lines.
      (if (string-match ":MMLYES:" template)
	  (setq template (replace-match yes t t template)))
      (if (string-match ":MMLNO:" template)
	  (setq template (replace-match no t t template)))
      ;; Return the modified template.
      (org-element-normalize-string template))))

(defun org-html--build-preamble (info)
  "Return document preamble as a string, or nil.
INFO is a plist used as a communication channel."
  (let ((preamble (plist-get info :html-preamble)))
    (when preamble
      (let ((preamble-contents
	     (if (functionp preamble) (funcall preamble info)
	       (let ((title (org-export-data (plist-get info :title) info))
		     (date (if (not (plist-get info :with-date)) ""
			     (org-export-data (plist-get info :date) info)))
		     (author (if (not (plist-get info :with-author)) ""
			       (org-export-data (plist-get info :author) info)))
		     (email (if (not (plist-get info :with-email)) ""
			      (plist-get info :email))))
		 (if (stringp preamble)
		     (format-spec preamble
				  `((?t . ,title) (?a . ,author)
				    (?d . ,date) (?e . ,email)))
		   (format-spec
		    (or (cadr (assoc (plist-get info :language)
				     org-html-preamble-format))
			(cadr (assoc "en" org-html-preamble-format)))
		    `((?t . ,title) (?a . ,author)
		      (?d . ,date) (?e . ,email))))))))
	(when (org-string-nw-p preamble-contents)
	  (concat (format "<div id=\"%s\">\n" (nth 0 org-html-divs))
		  (org-element-normalize-string preamble-contents)
		  "</div>\n"))))))

(defun org-html--build-postamble (info)
  "Return document postamble as a string, or nil.
INFO is a plist used as a communication channel."
  (let ((postamble (plist-get info :html-postamble)))
    (when postamble
      (let ((postamble-contents
	     (if (functionp postamble) (funcall postamble info)
	       (let ((date (if (not (plist-get info :with-date)) ""
			     (org-export-data (plist-get info :date) info)))
		     (author (let ((author (plist-get info :author)))
			       (and author (org-export-data author info))))
		     (email (mapconcat
			     (lambda (e)
			       (format "<a href=\"mailto:%s\">%s</a>" e e))
			     (split-string (plist-get info :email)  ",+ *")
			     ", "))
		     (html-validation-link (or org-html-validation-link ""))
		     (creator-info (plist-get info :creator)))
		 (cond ((stringp postamble)
			(format-spec postamble
				     `((?a . ,author) (?e . ,email)
				       (?d . ,date)   (?c . ,creator-info)
				       (?v . ,html-validation-link))))
		       ((eq postamble 'auto)
			(concat
			 (when (plist-get info :time-stamp-file)
			   (format "<p class=\"date\">%s: %s</p>\n"
				   (org-html--translate "Date" info)
				   date))
			 (when (and (plist-get info :with-author) author)
			   (format "<p class=\"author\">%s : %s</p>\n"
				   (org-html--translate "Author" info)
				   author))
			 (when (and (plist-get info :with-email) email)
			   (format "<p class=\"email\">%s </p>\n" email))
			 (when (plist-get info :with-creator)
			   (format "<p class=\"creator\">%s</p>\n"
				   creator-info))
			 html-validation-link "\n"))
		       (t (format-spec
			   (or (cadr (assoc (plist-get info :language)
					    org-html-postamble-format))
			       (cadr (assoc "en" org-html-postamble-format)))
			   `((?a . ,author) (?e . ,email)
			     (?d . ,date)   (?c . ,creator-info)
			     (?v . ,html-validation-link)))))))))
	(when (org-string-nw-p postamble-contents)
	  (concat
	   (format "<div id=\"%s\">\n" (nth 2 org-html-divs))
	   (org-element-normalize-string postamble-contents)
	   "</div>\n"))))))

(defun org-html-inner-template (contents info)
  "Return body of document string after HTML conversion.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options."
  (concat
   (format "<div id=\"%s\">\n" (nth 1 org-html-divs))
   ;; Document title.
   (format "<h1 class=\"title\">%s</h1>\n"
	   (org-export-data (plist-get info :title) info))
   ;; Table of contents.
   (let ((depth (plist-get info :with-toc)))
     (when depth (org-html-toc depth info)))
   ;; Document contents.
   contents
   ;; Footnotes section.
   (org-html-footnote-section info)
   ;; Bibliography.
   (org-html-bibliography)
   "\n</div>"))

(defun org-html-template (contents info)
  "Return complete document string after HTML conversion.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options."
  (concat
   (format
    (or (and (stringp org-html-xml-declaration)
	     org-html-xml-declaration)
	(cdr (assoc (plist-get info :html-extension)
		    org-html-xml-declaration))
	(cdr (assoc "html" org-html-xml-declaration))

	"")
    (or (and org-html-coding-system
	     (fboundp 'coding-system-get)
	     (coding-system-get org-html-coding-system 'mime-charset))
	"iso-8859-1"))
   "\n"
   "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"
	       \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n"
   (format "<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"%s\" xml:lang=\"%s\">\n"
	   (plist-get info :language) (plist-get info :language))
   "<head>\n"
   (org-html--build-meta-info info)
   (org-html--build-style info)
   (org-html--build-mathjax-config info)
   "</head>\n"
   "<body>\n"
   (let ((link-up (org-trim (plist-get info :html-link-up)))
	 (link-home (org-trim (plist-get info :html-link-home))))
     (unless (and (string= link-up "") (string= link-up ""))
       (format org-html-home/up-format
	       (or link-up link-home)
	       (or link-home link-up))))
   ;; Preamble.
   (org-html--build-preamble info)
   ;; Document contents.
   contents
   ;; Postamble.
   (org-html--build-postamble info)
   ;; Closing document.
   "</body>\n</html>"))

(defun org-html--translate (s info)
  "Translate string S according to specified language.
INFO is a plist used as a communication channel."
  (org-export-translate s :html info))

;;;; Anchor

(defun org-html--anchor (&optional id desc attributes)
  (let* ((name (and org-html-allow-name-attribute-in-anchors id))
	 (attributes (concat (and id (format " id=\"%s\"" id))
			     (and name (format " name=\"%s\"" name))
			     attributes)))
    (format "<a%s>%s</a>" attributes (or desc ""))))

;;;; Todo

(defun org-html--todo (todo)
  (when todo
    (format "<span class=\"%s %s%s\">%s</span>"
	    (if (member todo org-done-keywords) "done" "todo")
	    org-html-todo-kwd-class-prefix (org-html-fix-class-name todo)
	    todo)))

;;;; Tags

(defun org-html--tags (tags)
  (when tags
    (format "<span class=\"tag\">%s</span>"
	    (mapconcat
	     (lambda (tag)
	       (format "<span class=\"%s\">%s</span>"
		       (concat org-html-tag-class-prefix
			       (org-html-fix-class-name tag))
		       tag))
	     tags "&nbsp;"))))

;;;; Headline

(defun* org-html-format-headline
  (todo todo-type priority text tags
	&key level section-number headline-label &allow-other-keys)
  (let ((section-number
	 (when section-number
	   (format "<span class=\"section-number-%d\">%s</span> "
		   level section-number)))
	(todo (org-html--todo todo))
	(tags (org-html--tags tags)))
    (concat section-number todo (and todo " ") text
	    (and tags "&nbsp;&nbsp;&nbsp;") tags)))

;;;; Src Code

(defun org-html-fontify-code (code lang)
  "Color CODE with htmlize library.
CODE is a string representing the source code to colorize.  LANG
is the language used for CODE, as a string, or nil."
  (when code
    (cond
     ;; Case 1: No lang.  Possibly an example block.
     ((not lang)
      ;; Simple transcoding.
      (org-html-encode-plain-text code))
     ;; Case 2: No htmlize or an inferior version of htmlize
     ((not (and (require 'htmlize nil t) (fboundp 'htmlize-region-for-paste)))
      ;; Emit a warning.
      (message "Cannot fontify src block (htmlize.el >= 1.34 required)")
      ;; Simple transcoding.
      (org-html-encode-plain-text code))
     (t
      ;; Map language
      (setq lang (or (assoc-default lang org-src-lang-modes) lang))
      (let* ((lang-mode (and lang (intern (format "%s-mode" lang)))))
	(cond
	 ;; Case 1: Language is not associated with any Emacs mode
	 ((not (functionp lang-mode))
	  ;; Simple transcoding.
	  (org-html-encode-plain-text code))
	 ;; Case 2: Default.  Fontify code.
	 (t
	  ;; htmlize
	  (setq code (with-temp-buffer
		       ;; Switch to language-specific mode.
		       (funcall lang-mode)
		       (insert code)
		       ;; Fontify buffer.
		       (font-lock-fontify-buffer)
		       ;; Remove formatting on newline characters.
		       (save-excursion
			 (let ((beg (point-min))
			       (end (point-max)))
			   (goto-char beg)
			   (while (progn (end-of-line) (< (point) end))
			     (put-text-property (point) (1+ (point)) 'face nil)
			     (forward-char 1))))
		       (org-src-mode)
		       (set-buffer-modified-p nil)
		       ;; Htmlize region.
		       (org-export-htmlize-region-for-paste
			(point-min) (point-max))))
	  ;; Strip any encolosing <pre></pre> tags.
	  (if (string-match "<pre[^>]*>\n*\\([^\000]*\\)</pre>" code)
	      (match-string 1 code)
	    code))))))))

(defun org-html-do-format-code
  (code &optional lang refs retain-labels num-start)
  "Format CODE string as source code.
Optional arguments LANG, REFS, RETAIN-LABELS and NUM-START are,
respectively, the language of the source code, as a string, an
alist between line numbers and references (as returned by
`org-export-unravel-code'), a boolean specifying if labels should
appear in the source code, and the number associated to the first
line of code."
  (let* ((code-lines (org-split-string code "\n"))
	 (code-length (length code-lines))
	 (num-fmt
	  (and num-start
	       (format "%%%ds: "
		       (length (number-to-string (+ code-length num-start))))))
	 (code (org-html-fontify-code code lang)))
    (org-export-format-code
     code
     (lambda (loc line-num ref)
       (setq loc
	     (concat
	      ;; Add line number, if needed.
	      (when num-start
		(format "<span class=\"linenr\">%s</span>"
			(format num-fmt line-num)))
	      ;; Transcoded src line.
	      loc
	      ;; Add label, if needed.
	      (when (and ref retain-labels) (format " (%s)" ref))))
       ;; Mark transcoded line as an anchor, if needed.
       (if (not ref) loc
	 (format "<span id=\"coderef-%s\" class=\"coderef-off\">%s</span>"
		 ref loc)))
     num-start refs)))

(defun org-html-format-code (element info)
  "Format contents of ELEMENT as source code.
ELEMENT is either an example block or a src block.  INFO is
a plist used as a communication channel."
  (let* ((lang (org-element-property :language element))
	 ;; Extract code and references.
	 (code-info (org-export-unravel-code element))
	 (code (car code-info))
	 (refs (cdr code-info))
	 ;; Does the src block contain labels?
	 (retain-labels (org-element-property :retain-labels element))
	 ;; Does it have line numbers?
	 (num-start (case (org-element-property :number-lines element)
		      (continued (org-export-get-loc element info))
		      (new 0))))
    (org-html-do-format-code code lang refs retain-labels num-start)))



;;; Transcode Functions

;;;; Bold

(defun org-html-bold (bold contents info)
  "Transcode BOLD from Org to HTML.
CONTENTS is the text with bold markup.  INFO is a plist holding
contextual information."
  (format (or (cdr (assq 'bold org-html-text-markup-alist)) "%s")
	  contents))


;;;; Center Block

(defun org-html-center-block (center-block contents info)
  "Transcode a CENTER-BLOCK element from Org to HTML.
CONTENTS holds the contents of the block.  INFO is a plist
holding contextual information."
  (format "<div style=\"text-align: center\">\n%s</div>" contents))


;;;; Clock

(defun org-html-clock (clock contents info)
  "Transcode a CLOCK element from Org to HTML.
CONTENTS is nil.  INFO is a plist used as a communication
channel."
  (format "<p>
<span class=\"timestamp-wrapper\">
<span class=\"timestamp-kwd\">%s</span> <span class=\"timestamp\">%s</span>%s
</span>
</p>"
	  org-clock-string
	  (org-translate-time
	   (org-element-property :raw-value
				 (org-element-property :value clock)))
	  (let ((time (org-element-property :duration clock)))
	    (and time (format " <span class=\"timestamp\">(%s)</span>" time)))))


;;;; Code

(defun org-html-code (code contents info)
  "Transcode CODE from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual
information."
  (format (or (cdr (assq 'code org-html-text-markup-alist)) "%s")
	  (org-element-property :value code)))


;;;; Drawer

(defun org-html-drawer (drawer contents info)
  "Transcode a DRAWER element from Org to HTML.
CONTENTS holds the contents of the block.  INFO is a plist
holding contextual information."
  (if (functionp org-html-format-drawer-function)
      (funcall org-html-format-drawer-function
	       (org-element-property :drawer-name drawer)
	       contents)
    ;; If there's no user defined function: simply
    ;; display contents of the drawer.
    contents))


;;;; Dynamic Block

(defun org-html-dynamic-block (dynamic-block contents info)
  "Transcode a DYNAMIC-BLOCK element from Org to HTML.
CONTENTS holds the contents of the block.  INFO is a plist
holding contextual information.  See `org-export-data'."
  contents)


;;;; Entity

(defun org-html-entity (entity contents info)
  "Transcode an ENTITY object from Org to HTML.
CONTENTS are the definition itself.  INFO is a plist holding
contextual information."
  (org-element-property :html entity))


;;;; Example Block

(defun org-html-example-block (example-block contents info)
  "Transcode a EXAMPLE-BLOCK element from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual
information."
  (if (org-export-read-attribute :attr_html example-block :textarea)
      (org-html--textarea-block example-block)
    (format "<pre class=\"example\">\n%s</pre>"
	    (org-html-format-code example-block info))))


;;;; Export Snippet

(defun org-html-export-snippet (export-snippet contents info)
  "Transcode a EXPORT-SNIPPET object from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual
information."
  (when (eq (org-export-snippet-backend export-snippet) 'html)
    (org-element-property :value export-snippet)))


;;;; Export Block

(defun org-html-export-block (export-block contents info)
  "Transcode a EXPORT-BLOCK element from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual information."
  (when (string= (org-element-property :type export-block) "HTML")
    (org-remove-indentation (org-element-property :value export-block))))


;;;; Fixed Width

(defun org-html-fixed-width (fixed-width contents info)
  "Transcode a FIXED-WIDTH element from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual information."
  (format "<pre class=\"example\">\n%s</pre>"
	  (org-html-do-format-code
	   (org-remove-indentation
	    (org-element-property :value fixed-width)))))


;;;; Footnote Reference

(defun org-html-footnote-reference (footnote-reference contents info)
  "Transcode a FOOTNOTE-REFERENCE element from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual information."
  (concat
   ;; Insert separator between two footnotes in a row.
   (let ((prev (org-export-get-previous-element footnote-reference info)))
     (when (eq (org-element-type prev) 'footnote-reference)
       org-html-footnote-separator))
   (cond
    ((not (org-export-footnote-first-reference-p footnote-reference info))
     (org-html-format-footnote-reference
      (org-export-get-footnote-number footnote-reference info)
      "IGNORED" 100))
    ;; Inline definitions are secondary strings.
    ((eq (org-element-property :type footnote-reference) 'inline)
     (org-html-format-footnote-reference
      (org-export-get-footnote-number footnote-reference info)
      "IGNORED" 1))
    ;; Non-inline footnotes definitions are full Org data.
    (t (org-html-format-footnote-reference
	(org-export-get-footnote-number footnote-reference info)
	"IGNORED" 1)))))


;;;; Headline

(defun org-html-format-headline--wrap (headline info
						  &optional format-function
						  &rest extra-keys)
  "Transcode an HEADLINE element from Org to HTML.
CONTENTS holds the contents of the headline.  INFO is a plist
holding contextual information."
  (let* ((level (+ (org-export-get-relative-level headline info)
		   (1- org-html-toplevel-hlevel)))
	 (headline-number (org-export-get-headline-number headline info))
	 (section-number (and (not (org-export-low-level-p headline info))
			      (org-export-numbered-headline-p headline info)
			      (mapconcat 'number-to-string
					 headline-number ".")))
	 (todo (and (plist-get info :with-todo-keywords)
		    (let ((todo (org-element-property :todo-keyword headline)))
		      (and todo (org-export-data todo info)))))
	 (todo-type (and todo (org-element-property :todo-type headline)))
	 (priority (and (plist-get info :with-priority)
			(org-element-property :priority headline)))
	 (text (org-export-data (org-element-property :title headline) info))
	 (tags (and (plist-get info :with-tags)
		    (org-export-get-tags headline info)))
	 (headline-label (or (org-element-property :custom-id headline)
			     (concat "sec-" (mapconcat 'number-to-string
						       headline-number "-"))))
	 (format-function (cond
			   ((functionp format-function) format-function)
			   ((functionp org-html-format-headline-function)
			    (function*
			     (lambda (todo todo-type priority text tags
					   &allow-other-keys)
			       (funcall org-html-format-headline-function
					todo todo-type priority text tags))))
			   (t 'org-html-format-headline))))
    (apply format-function
    	   todo todo-type  priority text tags
    	   :headline-label headline-label :level level
    	   :section-number section-number extra-keys)))

(defun org-html-headline (headline contents info)
  "Transcode an HEADLINE element from Org to HTML.
CONTENTS holds the contents of the headline.  INFO is a plist
holding contextual information."
  ;; Empty contents?
  (setq contents (or contents ""))
  (let* ((numberedp (org-export-numbered-headline-p headline info))
	 (level (org-export-get-relative-level headline info))
	 (text (org-export-data (org-element-property :title headline) info))
	 (todo (and (plist-get info :with-todo-keywords)
		    (let ((todo (org-element-property :todo-keyword headline)))
		      (and todo (org-export-data todo info)))))
	 (todo-type (and todo (org-element-property :todo-type headline)))
	 (tags (and (plist-get info :with-tags)
		    (org-export-get-tags headline info)))
	 (priority (and (plist-get info :with-priority)
			(org-element-property :priority headline)))
	 (section-number (and (org-export-numbered-headline-p headline info)
			      (mapconcat 'number-to-string
					 (org-export-get-headline-number
					  headline info) ".")))
	 ;; Create the headline text.
	 (full-text (org-html-format-headline--wrap headline info)))
    (cond
     ;; Case 1: This is a footnote section: ignore it.
     ((org-element-property :footnote-section-p headline) nil)
     ;; Case 2. This is a deep sub-tree: export it as a list item.
     ;;         Also export as items headlines for which no section
     ;;         format has been found.
     ((org-export-low-level-p headline info)
      ;; Build the real contents of the sub-tree.
      (let* ((type (if numberedp 'ordered 'unordered))
	     (itemized-body (org-html-format-list-item
			     contents type nil nil full-text)))
	(concat
	 (and (org-export-first-sibling-p headline info)
	      (org-html-begin-plain-list type))
	 itemized-body
	 (and (org-export-last-sibling-p headline info)
	      (org-html-end-plain-list type)))))
     ;; Case 3. Standard headline.  Export it as a section.
     (t
      (let* ((section-number (mapconcat 'number-to-string
					(org-export-get-headline-number
					 headline info) "-"))
	     (ids (remove 'nil
			  (list (org-element-property :custom-id headline)
				(concat "sec-" section-number)
				(org-element-property :id headline))))
	     (preferred-id (car ids))
	     (extra-ids (cdr ids))
	     (extra-class (org-element-property :html-container-class headline))
	     (level1 (+ level (1- org-html-toplevel-hlevel))))
	(format "<div id=\"%s\" class=\"%s\">%s%s</div>\n"
		(format "outline-container-%s"
			(or (org-element-property :custom-id headline)
			    section-number))
		(concat (format "outline-%d" level1) (and extra-class " ")
			extra-class)
		(format "\n<h%d id=\"%s\">%s%s</h%d>\n"
			level1
			preferred-id
			(mapconcat
			 (lambda (x)
			   (let ((id (org-export-solidify-link-text
				      (if (org-uuidgen-p x) (concat "ID-" x)
					x))))
			     (org-html--anchor id)))
			 extra-ids "")
			full-text
			level1)
		contents))))))


;;;; Horizontal Rule

(defun org-html-horizontal-rule (horizontal-rule contents info)
  "Transcode an HORIZONTAL-RULE  object from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual information."
  "<hr/>")


;;;; Inline Src Block

(defun org-html-inline-src-block (inline-src-block contents info)
  "Transcode an INLINE-SRC-BLOCK element from Org to HTML.
CONTENTS holds the contents of the item.  INFO is a plist holding
contextual information."
  (let* ((org-lang (org-element-property :language inline-src-block))
	 (code (org-element-property :value inline-src-block)))
    (error "FIXME")))


;;;; Inlinetask

(defun org-html-format-section (text class &optional id)
  (let ((extra (concat (when id (format " id=\"%s\"" id)))))
    (concat (format "<div class=\"%s\"%s>\n" class extra) text "</div>\n")))

(defun org-html-inlinetask (inlinetask contents info)
  "Transcode an INLINETASK element from Org to HTML.
CONTENTS holds the contents of the block.  INFO is a plist
holding contextual information."
  (cond
   ;; If `org-html-format-inlinetask-function' is provided, call it
   ;; with appropriate arguments.
   ((functionp org-html-format-inlinetask-function)
    (let ((format-function
	   (function*
	    (lambda (todo todo-type priority text tags
		     &key contents &allow-other-keys)
	      (funcall org-html-format-inlinetask-function
		       todo todo-type priority text tags contents)))))
      (org-html-format-headline--wrap
       inlinetask info format-function :contents contents)))
   ;; Otherwise, use a default template.
   (t (format "<div class=\"inlinetask\">\n<b>%s</b><br/>\n%s</div>"
	      (org-html-format-headline--wrap inlinetask info)
	      contents))))


;;;; Italic

(defun org-html-italic (italic contents info)
  "Transcode ITALIC from Org to HTML.
CONTENTS is the text with italic markup.  INFO is a plist holding
contextual information."
  (format (or (cdr (assq 'italic org-html-text-markup-alist)) "%s") contents))


;;;; Item

(defun org-html-checkbox (checkbox)
  (case checkbox (on "<code>[X]</code>")
	(off "<code>[&nbsp;]</code>")
	(trans "<code>[-]</code>")
	(t "")))

(defun org-html-format-list-item (contents type checkbox
					     &optional term-counter-id
					     headline)
  (let ((checkbox (concat (org-html-checkbox checkbox) (and checkbox " "))))
    (concat
     (case type
       (ordered
	(let* ((counter term-counter-id)
	       (extra (if counter (format " value=\"%s\"" counter) "")))
	  (concat
	   (format "<li%s>" extra)
	   (when headline (concat headline "<br/>")))))
       (unordered
	(let* ((id term-counter-id)
	       (extra (if id (format " id=\"%s\"" id) "")))
	  (concat
	   (format "<li%s>" extra)
	   (when headline (concat headline "<br/>")))))
       (descriptive
	(let* ((term term-counter-id))
	  (setq term (or term "(no term)"))
	  ;; Check-boxes in descriptive lists are associated to tag.
	  (concat (format "<dt> %s </dt>"
			  (concat checkbox term))
		  "<dd>"))))
     (unless (eq type 'descriptive) checkbox)
     contents
     (case type
       (ordered "</li>")
       (unordered "</li>")
       (descriptive "</dd>")))))

(defun org-html-item (item contents info)
  "Transcode an ITEM element from Org to HTML.
CONTENTS holds the contents of the item.  INFO is a plist holding
contextual information."
  (let* ((plain-list (org-export-get-parent item))
	 (type (org-element-property :type plain-list))
	 (counter (org-element-property :counter item))
	 (checkbox (org-element-property :checkbox item))
	 (tag (let ((tag (org-element-property :tag item)))
		(and tag (org-export-data tag info)))))
    (org-html-format-list-item
     contents type checkbox (or tag counter))))


;;;; Keyword

(defun org-html-keyword (keyword contents info)
  "Transcode a KEYWORD element from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual information."
  (let ((key (org-element-property :key keyword))
	(value (org-element-property :value keyword)))
    (cond
     ((string= key "HTML") value)
     ;; Invisible targets.
     ((string= key "TARGET") nil)
     ((string= key "TOC")
      (let ((value (downcase value)))
	(cond
	 ((string-match "\\<headlines\\>" value)
	  (let ((depth (or (and (string-match "[0-9]+" value)
				(string-to-number (match-string 0 value)))
			   (plist-get info :with-toc))))
	    (org-html-toc depth info)))
	 ((string= "tables" value) "\\listoftables")
	 ((string= "figures" value) "\\listoffigures")
	 ((string= "listings" value)
	  (cond
	   ;; At the moment, src blocks with a caption are wrapped
	   ;; into a figure environment.
	   (t "\\listoffigures")))))))))


;;;; Latex Environment

(defun org-html-format-latex (latex-frag processing-type)
  "Format LaTeX fragments into HTML."
  (let ((cache-relpath "") (cache-dir "") bfn)
    (unless (eq processing-type 'mathjax)
      (setq bfn (buffer-file-name)
	    cache-relpath
	    (concat "ltxpng/"
		    (file-name-sans-extension
		     (file-name-nondirectory bfn)))
	    cache-dir (file-name-directory bfn)))
    (with-temp-buffer
      (insert latex-frag)
      (org-format-latex cache-relpath cache-dir nil "Creating LaTeX Image..."
			nil nil processing-type)
      (buffer-string))))

(defun org-html-latex-environment (latex-environment contents info)
  "Transcode a LATEX-ENVIRONMENT element from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual information."
  (let ((processing-type (plist-get info :with-latex))
	(latex-frag (org-remove-indentation
		     (org-element-property :value latex-environment)))
	(caption (org-export-data
		  (org-export-get-caption latex-environment) info))
	(attr nil)			; FIXME
	(label (org-element-property :name latex-environment)))
    (cond
     ((memq processing-type '(t mathjax))
      (org-html-format-latex latex-frag 'mathjax))
     ((eq processing-type 'dvipng)
      (let* ((formula-link (org-html-format-latex
			    latex-frag processing-type)))
	(when (and formula-link
		   (string-match "file:\\([^]]*\\)" formula-link))
	  (org-html-format-inline-image
	   (match-string 1 formula-link) caption label attr t))))
     (t latex-frag))))


;;;; Latex Fragment

(defun org-html-latex-fragment (latex-fragment contents info)
  "Transcode a LATEX-FRAGMENT object from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual information."
  (let ((latex-frag (org-element-property :value latex-fragment))
	(processing-type (plist-get info :with-latex)))
    (case processing-type
      ((t mathjax)
       (org-html-format-latex latex-frag 'mathjax))
      (dvipng
       (let* ((formula-link (org-html-format-latex
			     latex-frag processing-type)))
	 (when (and formula-link
		    (string-match "file:\\([^]]*\\)" formula-link))
	   (org-html-format-inline-image
	    (match-string 1 formula-link)))))
      (t latex-frag))))


;;;; Line Break

(defun org-html-line-break (line-break contents info)
  "Transcode a LINE-BREAK object from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual information."
  "<br/>\n")


;;;; Link

(defun org-html-link--inline-image (link desc info)
  "Return HTML code for an inline image.
LINK is the link pointing to the inline image.  INFO is a plist
used as a communication channel."
  (let* ((type (org-element-property :type link))
	 (raw-path (org-element-property :path link))
	 (path (cond ((member type '("http" "https"))
		      (concat type ":" raw-path))
		     ((file-name-absolute-p raw-path)
		      (expand-file-name raw-path))
		     (t raw-path)))
	 (parent (org-export-get-parent-element link))
	 (caption (org-export-data (org-export-get-caption parent) info))
	 (label (org-element-property :name parent))
	 ;; Retrieve latex attributes from the element around.
	 (attr (let ((raw-attr
		      (mapconcat #'identity
				 (org-element-property :attr_html parent)
				 " ")))
		 (unless (string= raw-attr "") raw-attr))))
    ;; Now clear ATTR from any special keyword and set a default
    ;; value if nothing is left.
    (setq attr (if (not attr) "" (org-trim attr)))
    ;; Return proper string, depending on DISPOSITION.
    (org-html-format-inline-image
     path caption label attr (org-html-standalone-image-p link info))))

(defvar org-html-standalone-image-predicate)
(defun org-html-standalone-image-p (element info &optional predicate)
  "Test if ELEMENT is a standalone image for the purpose HTML export.
INFO is a plist holding contextual information.

Return non-nil, if ELEMENT is of type paragraph and it's sole
content, save for whitespaces, is a link that qualifies as an
inline image.

Return non-nil, if ELEMENT is of type link and it's containing
paragraph has no other content save for leading and trailing
whitespaces.

Return nil, otherwise.

Bind `org-html-standalone-image-predicate' to constrain
paragraph further.  For example, to check for only captioned
standalone images, do the following.

  \(setq org-html-standalone-image-predicate
	\(lambda \(paragraph\)
	  \(org-element-property :caption paragraph\)\)\)"
  (let ((paragraph (case (org-element-type element)
		     (paragraph element)
		     (link (and (org-export-inline-image-p
				 element org-html-inline-image-rules)
				(org-export-get-parent element)))
		     (t nil))))
    (when (eq (org-element-type paragraph) 'paragraph)
      (when (or (not (and (boundp 'org-html-standalone-image-predicate)
			  (functionp org-html-standalone-image-predicate)))
		(funcall org-html-standalone-image-predicate paragraph))
	(let ((contents (org-element-contents paragraph)))
	  (loop for x in contents
		with inline-image-count = 0
		always (cond
			((eq (org-element-type x) 'plain-text)
			 (not (org-string-nw-p x)))
			((eq (org-element-type x) 'link)
			 (when (org-export-inline-image-p
				x org-html-inline-image-rules)
			   (= (incf inline-image-count) 1)))
			(t nil))))))))

(defun org-html-link (link desc info)
  "Transcode a LINK object from Org to HTML.

DESC is the description part of the link, or the empty string.
INFO is a plist holding contextual information.  See
`org-export-data'."
  (let* ((--link-org-files-as-html-maybe
	  (function
	   (lambda (raw-path info)
	     "Treat links to `file.org' as links to `file.html', if needed.
           See `org-html-link-org-files-as-html'."
	     (cond
	      ((and org-html-link-org-files-as-html
		    (string= ".org"
			     (downcase (file-name-extension raw-path "."))))
	       (concat (file-name-sans-extension raw-path) "."
		       (plist-get info :html-extension)))
	      (t raw-path)))))
	 (type (org-element-property :type link))
	 (raw-path (org-element-property :path link))
	 ;; Ensure DESC really exists, or set it to nil.
	 (desc (and (not (string= desc "")) desc))
	 (path (cond
		((member type '("http" "https" "ftp" "mailto"))
		 (concat type ":" raw-path))
		((string= type "file")
		 ;; Treat links to ".org" files as ".html", if needed.
		 (setq raw-path (funcall --link-org-files-as-html-maybe
					 raw-path info))
		 ;; If file path is absolute, prepend it with protocol
		 ;; component - "file://".
		 (if (not (file-name-absolute-p raw-path)) raw-path
		   (concat "file://" (expand-file-name raw-path))))
		(t raw-path)))
	 attributes protocol)
    ;; Extract attributes from parent's paragraph.
    (and (setq attributes
	       (mapconcat
		'identity
		(let ((att (org-element-property
			    :attr_html (org-export-get-parent-element link))))
		  (unless (and desc att (string-match (regexp-quote (car att)) desc)) att))
		" "))
	 (setq attributes (concat " " attributes)))

    (cond
     ;; Image file.
     ((and (or (eq t org-html-inline-images)
	       (and org-html-inline-images (not desc)))
	   (org-export-inline-image-p link org-html-inline-image-rules))
      (org-html-link--inline-image link desc info))
     ;; Radio target: Transcode target's contents and use them as
     ;; link's description.
     ((string= type "radio")
      (let ((destination (org-export-resolve-radio-link link info)))
	(when destination
	  (format "<a href=\"#%s\"%s>%s</a>"
		  (org-export-solidify-link-text path)
		  attributes
		  (org-export-data (org-element-contents destination) info)))))
     ;; Links pointing to an headline: Find destination and build
     ;; appropriate referencing command.
     ((member type '("custom-id" "fuzzy" "id"))
      (let ((destination (if (string= type "fuzzy")
			     (org-export-resolve-fuzzy-link link info)
			   (org-export-resolve-id-link link info))))
	(case (org-element-type destination)
	  ;; ID link points to an external file.
	  (plain-text
	   (let ((fragment (concat "ID-" path))
		 ;; Treat links to ".org" files as ".html", if needed.
		 (path (funcall --link-org-files-as-html-maybe
				destination info)))
	     (format "<a href=\"%s#%s\"%s>%s</a>"
		     path fragment attributes (or desc destination))))
	  ;; Fuzzy link points nowhere.
	  ((nil)
	   (format "<i>%s</i>"
		   (or desc
		       (org-export-data
			(org-element-property :raw-link link) info))))
	  ;; Fuzzy link points to an invisible target.
	  (keyword nil)
	  ;; Link points to an headline.
	  (headline
	   (let ((href
		  ;; What href to use?
		  (cond
		   ;; Case 1: Headline is linked via it's CUSTOM_ID
		   ;; property.  Use CUSTOM_ID.
		   ((string= type "custom-id")
		    (org-element-property :custom-id destination))
		   ;; Case 2: Headline is linked via it's ID property
		   ;; or through other means.  Use the default href.
		   ((member type '("id" "fuzzy"))
		    (format "sec-%s"
			    (mapconcat 'number-to-string
				       (org-export-get-headline-number
					destination info) "-")))
		   (t (error "Shouldn't reach here"))))
		 ;; What description to use?
		 (desc
		  ;; Case 1: Headline is numbered and LINK has no
		  ;; description or LINK's description matches
		  ;; headline's title.  Display section number.
		  (if (and (org-export-numbered-headline-p destination info)
			   (or (not desc)
			       (string= desc (org-element-property
					      :raw-value destination))))
		      (mapconcat 'number-to-string
				 (org-export-get-headline-number
				  destination info) ".")
		    ;; Case 2: Either the headline is un-numbered or
		    ;; LINK has a custom description.  Display LINK's
		    ;; description or headline's title.
		    (or desc (org-export-data (org-element-property
					       :title destination) info)))))
	     (format "<a href=\"#%s\"%s>%s</a>"
		     (org-export-solidify-link-text href) attributes desc)))
	  ;; Fuzzy link points to a target.  Do as above.
	  (t
	   (let ((path (org-export-solidify-link-text path)) number)
	     (unless desc
	       (setq number (cond
			     ((org-html-standalone-image-p destination info)
			      (org-export-get-ordinal
			       (assoc 'link (org-element-contents destination))
			       info 'link 'org-html-standalone-image-p))
			     (t (org-export-get-ordinal destination info))))
	       (setq desc (when number
			    (if (atom number) (number-to-string number)
			      (mapconcat 'number-to-string number ".")))))
	     (format "<a href=\"#%s\"%s>%s</a>"
		     path attributes (or desc "FIXME")))))))
     ;; Coderef: replace link with the reference name or the
     ;; equivalent line number.
     ((string= type "coderef")
      (let ((fragment (concat "coderef-" path)))
	(format "<a href=\"#%s\" %s%s>%s</a>"
		fragment
		(format (concat "class=\"coderef\""
				" onmouseover=\"CodeHighlightOn(this, '%s');\""
				" onmouseout=\"CodeHighlightOff(this, '%s');\"")
			fragment fragment)
		attributes
		(format (org-export-get-coderef-format path desc)
			(org-export-resolve-coderef path info)))))
     ;; Link type is handled by a special function.
     ((functionp (setq protocol (nth 2 (assoc type org-link-protocols))))
      (funcall protocol (org-link-unescape path) desc 'html))
     ;; External link with a description part.
     ((and path desc) (format "<a href=\"%s\"%s>%s</a>" path attributes desc))
     ;; External link without a description part.
     (path (format "<a href=\"%s\"%s>%s</a>" path attributes path))
     ;; No path, only description.  Try to do something useful.
     (t (format "<i>%s</i>" desc)))))


;;;; Paragraph

(defun org-html-paragraph (paragraph contents info)
  "Transcode a PARAGRAPH element from Org to HTML.
CONTENTS is the contents of the paragraph, as a string.  INFO is
the plist used as a communication channel."
  (let* ((style nil)			; FIXME
	 (class (cdr (assoc style '((footnote . "footnote")
				    (verse . nil)))))
	 (extra (if class (format " class=\"%s\"" class) ""))
	 (parent (org-export-get-parent paragraph)))
    (cond
     ((and (eq (org-element-type parent) 'item)
	   (= (org-element-property :begin paragraph)
	      (org-element-property :contents-begin parent)))
      ;; leading paragraph in a list item have no tags
      contents)
     ((org-html-standalone-image-p paragraph info)
      ;; standalone image
      contents)
     (t (format "<p%s>\n%s</p>" extra contents)))))


;;;; Plain List

(defun org-html-begin-plain-list (type &optional arg1)
  (case type
    (ordered
     (format "<ol class=\"org-ol\"%s>" (if arg1		; FIXME
			  (format " start=\"%d\"" arg1)
			"")))
    (unordered "<ul class=\"org-ul\">")
    (descriptive "<dl class=\"org-dl\">")))

(defun org-html-end-plain-list (type)
  (case type
    (ordered "</ol>")
    (unordered "</ul>")
    (descriptive "</dl>")))

(defun org-html-plain-list (plain-list contents info)
  "Transcode a PLAIN-LIST element from Org to HTML.
CONTENTS is the contents of the list.  INFO is a plist holding
contextual information."
  (let* (arg1 ;; FIXME
	 (type (org-element-property :type plain-list)))
    (format "%s\n%s%s"
	    (org-html-begin-plain-list type)
	    contents (org-html-end-plain-list type))))

;;;; Plain Text

(defun org-html-convert-special-strings (string)
  "Convert special characters in STRING to HTML."
  (let ((all org-html-special-string-regexps)
	e a re rpl start)
    (while (setq a (pop all))
      (setq re (car a) rpl (cdr a) start 0)
      (while (string-match re string start)
	(setq string (replace-match rpl t nil string))))
    string))

(defun org-html-encode-plain-text (text)
  "Convert plain text characters to HTML equivalent.
Possible conversions are set in `org-export-html-protect-char-alist'."
  (mapc
   (lambda (pair)
     (setq text (replace-regexp-in-string (car pair) (cdr pair) text t t)))
   org-html-protect-char-alist)
  text)

(defun org-html-plain-text (text info)
  "Transcode a TEXT string from Org to HTML.
TEXT is the string to transcode.  INFO is a plist holding
contextual information."
  (let ((output text))
    ;; Protect following characters: <, >, &.
    (setq output (org-html-encode-plain-text output))
    ;; Handle smart quotes.  Be sure to provide original string since
    ;; OUTPUT may have been modified.
    (when (plist-get info :with-smart-quotes)
      (setq output (org-export-activate-smart-quotes output :html info text)))
    ;; Handle special strings.
    (when (plist-get info :with-special-strings)
      (setq output (org-html-convert-special-strings output)))
    ;; Handle break preservation if required.
    (when (plist-get info :preserve-breaks)
      (setq output
	    (replace-regexp-in-string
	     "\\(\\\\\\\\\\)?[ \t]*\n" "<br/>\n" output)))
    ;; Return value.
    output))


;; Planning

(defun org-html-planning (planning contents info)
  "Transcode a PLANNING element from Org to HTML.
CONTENTS is nil.  INFO is a plist used as a communication
channel."
  (let ((span-fmt "<span class=\"timestamp-kwd\">%s</span> <span class=\"timestamp\">%s</span>"))
    (format
     "<p><span class=\"timestamp-wrapper\">%s</span></p>"
     (mapconcat
      'identity
      (delq nil
	    (list
	     (let ((closed (org-element-property :closed planning)))
	       (when closed
		 (format span-fmt org-closed-string
			 (org-translate-time
			  (org-element-property :raw-value closed)))))
	     (let ((deadline (org-element-property :deadline planning)))
	       (when deadline
		 (format span-fmt org-deadline-string
			 (org-translate-time
			  (org-element-property :raw-value deadline)))))
	     (let ((scheduled (org-element-property :scheduled planning)))
	       (when scheduled
		 (format span-fmt org-scheduled-string
			 (org-translate-time
			  (org-element-property :raw-value scheduled)))))))
      " "))))


;;;; Property Drawer

(defun org-html-property-drawer (property-drawer contents info)
  "Transcode a PROPERTY-DRAWER element from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual
information."
  ;; The property drawer isn't exported but we want separating blank
  ;; lines nonetheless.
  "")


;;;; Quote Block

(defun org-html-quote-block (quote-block contents info)
  "Transcode a QUOTE-BLOCK element from Org to HTML.
CONTENTS holds the contents of the block.  INFO is a plist
holding contextual information."
  (format "<blockquote>\n%s</blockquote>" contents))


;;;; Quote Section

(defun org-html-quote-section (quote-section contents info)
  "Transcode a QUOTE-SECTION element from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual information."
  (let ((value (org-remove-indentation
		(org-element-property :value quote-section))))
    (when value (format "<pre>\n%s</pre>" value))))


;;;; Section

(defun org-html-section (section contents info)
  "Transcode a SECTION element from Org to HTML.
CONTENTS holds the contents of the section.  INFO is a plist
holding contextual information."
  (let ((parent (org-export-get-parent-headline section)))
    ;; Before first headline: no container, just return CONTENTS.
    (if (not parent) contents
      ;; Get div's class and id references.
      (let* ((class-num (+ (org-export-get-relative-level parent info)
			   (1- org-html-toplevel-hlevel)))
	     (section-number
	      (mapconcat
	       'number-to-string
	       (org-export-get-headline-number parent info) "-")))
        ;; Build return value.
        (format "<div class=\"outline-text-%d\" id=\"text-%s\">\n%s</div>"
                class-num
		(or (org-element-property :custom-id parent) section-number)
		contents)))))

;;;; Radio Target

(defun org-html-radio-target (radio-target text info)
  "Transcode a RADIO-TARGET object from Org to HTML.
TEXT is the text of the target.  INFO is a plist holding
contextual information."
  (let ((id (org-export-solidify-link-text
	     (org-element-property :value radio-target))))
    (org-html--anchor id text)))


;;;; Special Block

(defun org-html-special-block (special-block contents info)
  "Transcode a SPECIAL-BLOCK element from Org to HTML.
CONTENTS holds the contents of the block.  INFO is a plist
holding contextual information."
  (format "<div class=\"%s\">\n%s\n</div>"
	  (downcase (org-element-property :type special-block))
	  contents))


;;;; Src Block

(defun org-html-src-block (src-block contents info)
  "Transcode a SRC-BLOCK element from Org to HTML.
CONTENTS holds the contents of the item.  INFO is a plist holding
contextual information."
  (if (org-export-read-attribute :attr_html src-block :textarea)
      (org-html--textarea-block src-block)
    (let ((lang (org-element-property :language src-block))
	  (caption (org-export-get-caption src-block))
	  (code (org-html-format-code src-block info)))
      (if (not lang) (format "<pre class=\"example\">\n%s</pre>" code)
	(format "<div class=\"org-src-container\">\n%s%s\n</div>"
		(if (not caption) ""
		  (format "<label class=\"org-src-name\">%s</label>"
			  (org-export-data caption info)))
		(format "\n<pre class=\"src src-%s\">%s</pre>" lang code))))))


;;;; Statistics Cookie

(defun org-html-statistics-cookie (statistics-cookie contents info)
  "Transcode a STATISTICS-COOKIE object from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual information."
  (let ((cookie-value (org-element-property :value statistics-cookie)))
    (format "<code>%s</code>" cookie-value)))


;;;; Strike-Through

(defun org-html-strike-through (strike-through contents info)
  "Transcode STRIKE-THROUGH from Org to HTML.
CONTENTS is the text with strike-through markup.  INFO is a plist
holding contextual information."
  (format (or (cdr (assq 'strike-through org-html-text-markup-alist)) "%s")
	  contents))


;;;; Subscript

(defun org-html-subscript (subscript contents info)
  "Transcode a SUBSCRIPT object from Org to HTML.
CONTENTS is the contents of the object.  INFO is a plist holding
contextual information."
  (format "<sub>%s</sub>" contents))


;;;; Superscript

(defun org-html-superscript (superscript contents info)
  "Transcode a SUPERSCRIPT object from Org to HTML.
CONTENTS is the contents of the object.  INFO is a plist holding
contextual information."
  (format "<sup>%s</sup>" contents))


;;;; Tabel Cell

(defun org-html-table-cell (table-cell contents info)
  "Transcode a TABLE-CELL element from Org to HTML.
CONTENTS is nil.  INFO is a plist used as a communication
channel."
  (let* ((table-row (org-export-get-parent table-cell))
	 (table (org-export-get-parent-table table-cell))
	 (cell-attrs
	  (if (not org-html-table-align-individual-fields) ""
	    (format (if (and (boundp 'org-html-format-table-no-css)
			     org-html-format-table-no-css)
			" align=\"%s\"" " class=\"%s\"")
		    (org-export-table-cell-alignment table-cell info)))))
    (when (or (not contents) (string= "" (org-trim contents)))
      (setq contents "&nbsp;"))
    (cond
     ((and (org-export-table-has-header-p table info)
	   (= 1 (org-export-table-row-group table-row info)))
      (concat "\n" (format (car org-html-table-header-tags) "col" cell-attrs)
	      contents (cdr org-html-table-header-tags)))
     ((and org-html-table-use-header-tags-for-first-column
  	   (zerop (cdr (org-export-table-cell-address table-cell info))))
      (concat "\n" (format (car org-html-table-header-tags) "row" cell-attrs)
	      contents (cdr org-html-table-header-tags)))
     (t (concat "\n" (format (car org-html-table-data-tags) cell-attrs)
		contents (cdr org-html-table-data-tags))))))


;;;; Table Row

(defun org-html-table-row (table-row contents info)
  "Transcode a TABLE-ROW element from Org to HTML.
CONTENTS is the contents of the row.  INFO is a plist used as a
communication channel."
  ;; Rules are ignored since table separators are deduced from
  ;; borders of the current row.
  (when (eq (org-element-property :type table-row) 'standard)
    (let* ((first-rowgroup-p (= 1 (org-export-table-row-group table-row info)))
	   (rowgroup-tags
	    (cond
	     ;; Case 1: Row belongs to second or subsequent rowgroups.
	     ((not (= 1 (org-export-table-row-group table-row info)))
	      '("<tbody>" . "\n</tbody>"))
	     ;; Case 2: Row is from first rowgroup.  Table has >=1 rowgroups.
	     ((org-export-table-has-header-p
	       (org-export-get-parent-table table-row) info)
	      '("<thead>" . "\n</thead>"))
	     ;; Case 2: Row is from first and only row group.
	     (t '("<tbody>" . "\n</tbody>")))))
      (concat
       ;; Begin a rowgroup?
       (when (org-export-table-row-starts-rowgroup-p table-row info)
	 (car rowgroup-tags))
       ;; Actual table row
       (concat "\n" (eval (car org-html-table-row-tags))
	       contents
	       "\n"
	       (eval (cdr org-html-table-row-tags)))
       ;; End a rowgroup?
       (when (org-export-table-row-ends-rowgroup-p table-row info)
	 (cdr rowgroup-tags))))))


;;;; Table

(defun org-html-table-first-row-data-cells (table info)
  (let ((table-row
	 (org-element-map table 'table-row
	   (lambda (row)
	     (unless (eq (org-element-property :type row) 'rule) row))
	   info 'first-match))
	(special-column-p (org-export-table-has-special-column-p table)))
    (if (not special-column-p) (org-element-contents table-row)
      (cdr (org-element-contents table-row)))))

(defun org-html-table--table.el-table (table info)
  (when (eq (org-element-property :type table) 'table.el)
    (require 'table)
    (let ((outbuf (with-current-buffer
		      (get-buffer-create "*org-export-table*")
		    (erase-buffer) (current-buffer))))
      (with-temp-buffer
	(insert (org-element-property :value table))
	(goto-char 1)
	(re-search-forward "^[ \t]*|[^|]" nil t)
	(table-generate-source 'html outbuf))
      (with-current-buffer outbuf
	(prog1 (org-trim (buffer-string))
	  (kill-buffer) )))))

(defun org-html-table (table contents info)
  "Transcode a TABLE element from Org to HTML.
CONTENTS is the contents of the table.  INFO is a plist holding
contextual information."
  (case (org-element-property :type table)
    ;; Case 1: table.el table.  Convert it using appropriate tools.
    (table.el (org-html-table--table.el-table table info))
    ;; Case 2: Standard table.
    (t
     (let* ((label (org-element-property :name table))
	    (caption (org-export-get-caption table))
	    (attributes (mapconcat #'identity
				   (org-element-property :attr_html table)
				   " "))
	    (alignspec
	     (if (and (boundp 'org-html-format-table-no-css)
		      org-html-format-table-no-css)
		 "align=\"%s\"" "class=\"%s\""))
	    (table-column-specs
	     (function
	      (lambda (table info)
		(mapconcat
		 (lambda (table-cell)
		   (let ((alignment (org-export-table-cell-alignment
				     table-cell info)))
		     (concat
		      ;; Begin a colgroup?
		      (when (org-export-table-cell-starts-colgroup-p
			     table-cell info)
			"\n<colgroup>")
		      ;; Add a column.  Also specify it's alignment.
		      (format "\n<col %s/>" (format alignspec alignment))
		      ;; End a colgroup?
		      (when (org-export-table-cell-ends-colgroup-p
			     table-cell info)
			"\n</colgroup>"))))
		 (org-html-table-first-row-data-cells table info) "\n"))))
	    (table-attributes
	     (let ((table-tag (plist-get info :html-table-tag)))
	       (concat
		(and (string-match  "<table\\(.*\\)>" table-tag)
		     (match-string 1 table-tag))
		(and label (format " id=\"%s\""
				   (org-export-solidify-link-text label)))
		(unless (string= attributes "")
		  (concat " " attributes))))))
       ;; Remove last blank line.
       (setq contents (substring contents 0 -1))
       (format "<table%s>\n%s\n%s\n%s\n</table>"
	       table-attributes
	       (if (not caption) ""
		 (format "<caption>%s</caption>"
			 (org-export-data caption info)))
	       (funcall table-column-specs table info)
	       contents)))))


;;;; Target

(defun org-html-target (target contents info)
  "Transcode a TARGET object from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual
information."
  (let ((id (org-export-solidify-link-text
	     (org-element-property :value target))))
    (org-html--anchor id)))


;;;; Timestamp

(defun org-html-timestamp (timestamp contents info)
  "Transcode a TIMESTAMP object from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual
information."
  (let ((value (org-html-plain-text
		(org-timestamp-translate timestamp) info)))
    (format "<span class=\"timestamp-wrapper\"><span class=\"timestamp\">%s</span></span>"
	    (replace-regexp-in-string "--" "&ndash;" value))))


;;;; Underline

(defun org-html-underline (underline contents info)
  "Transcode UNDERLINE from Org to HTML.
CONTENTS is the text with underline markup.  INFO is a plist
holding contextual information."
  (format (or (cdr (assq 'underline org-html-text-markup-alist)) "%s")
	  contents))


;;;; Verbatim

(defun org-html-verbatim (verbatim contents info)
  "Transcode VERBATIM from Org to HTML.
CONTENTS is nil.  INFO is a plist holding contextual
information."
  (format (or (cdr (assq 'verbatim org-html-text-markup-alist)) "%s")
	  (org-element-property :value verbatim)))


;;;; Verse Block

(defun org-html-verse-block (verse-block contents info)
  "Transcode a VERSE-BLOCK element from Org to HTML.
CONTENTS is verse block contents.  INFO is a plist holding
contextual information."
  ;; Replace each newline character with line break.  Also replace
  ;; each blank line with a line break.
  (setq contents (replace-regexp-in-string
		  "^ *\\\\\\\\$" "<br/>\n"
		  (replace-regexp-in-string
		   "\\(\\\\\\\\\\)?[ \t]*\n" " <br/>\n" contents)))
  ;; Replace each white space at beginning of a line with a
  ;; non-breaking space.
  (while (string-match "^[ \t]+" contents)
    (let* ((num-ws (length (match-string 0 contents)))
	   (ws (let (out) (dotimes (i num-ws out)
			    (setq out (concat out "&nbsp;"))))))
      (setq contents (replace-match ws nil t contents))))
  (format "<p class=\"verse\">\n%s</p>" contents))



;;; Filter Functions

(defun org-html-final-function (contents backend info)
  (if (not org-html-pretty-output) contents
    (with-temp-buffer
      (html-mode)
      (insert contents)
      (indent-region (point-min) (point-max))
      (buffer-substring-no-properties (point-min) (point-max)))))



;;; End-user functions

;;;###autoload
(defun org-html-export-as-html
  (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to an HTML buffer.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting buffer should be accessible
through the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

When optional argument BODY-ONLY is non-nil, only write code
between \"<body>\" and \"</body>\" tags.

EXT-PLIST, when provided, is a property list with external
parameters overriding Org default settings, but still inferior to
file-local settings.

Export is done in a buffer named \"*Org HTML Export*\", which
will be displayed when `org-export-show-temporary-export-buffer'
is non-nil."
  (interactive)
  (if async
      (org-export-async-start
	  (lambda (output)
	    (with-current-buffer (get-buffer-create "*Org HTML Export*")
	      (erase-buffer)
	      (insert output)
	      (goto-char (point-min))
	      (funcall org-html-display-buffer-mode)
	      (org-export-add-to-stack (current-buffer) 'html)))
	`(org-export-as 'html ,subtreep ,visible-only ,body-only ',ext-plist))
    (let ((outbuf (org-export-to-buffer
		   'html "*Org HTML Export*"
		   subtreep visible-only body-only ext-plist)))
      ;; Set major mode.
      (with-current-buffer outbuf (funcall org-html-display-buffer-mode))
      (when org-export-show-temporary-export-buffer
	(switch-to-buffer-other-window outbuf)))))

;;;###autoload
(defun org-html-export-to-html
  (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to a HTML file.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting file should be accessible through
the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

When optional argument BODY-ONLY is non-nil, only write code
between \"<body>\" and \"</body>\" tags.

EXT-PLIST, when provided, is a property list with external
parameters overriding Org default settings, but still inferior to
file-local settings.

Return output file's name."
  (interactive)
  (let* ((extension (concat "." org-html-extension))
	 (file (org-export-output-file-name extension subtreep))
	 (org-export-coding-system org-html-coding-system))
    (if async
	(org-export-async-start
	    (lambda (f) (org-export-add-to-stack f 'html))
	  (let ((org-export-coding-system org-html-coding-system))
	    `(expand-file-name
	      (org-export-to-file
	       'html ,file ,subtreep ,visible-only ,body-only ',ext-plist))))
      (let ((org-export-coding-system org-html-coding-system))
	(org-export-to-file
	 'html file subtreep visible-only body-only ext-plist)))))

;;;###autoload
(defun org-html-publish-to-html (plist filename pub-dir)
  "Publish an org file to HTML.

FILENAME is the filename of the Org file to be published.  PLIST
is the property list for the given project.  PUB-DIR is the
publishing directory.

Return output file name."
  (org-publish-org-to 'html filename ".html" plist pub-dir))



;;; FIXME

;;;; org-format-table-html
;;;; org-format-org-table-html
;;;; org-format-table-table-html
;;;; org-table-number-fraction
;;;; org-table-number-regexp
;;;; org-html-table-caption-above

;;;; org-html-with-timestamp
;;;; org-html-html-helper-timestamp

;;;; org-html-toplevel-hlevel
;;;; org-html-special-string-regexps
;;;; org-html-inline-images
;;;; org-html-inline-image-extensions
;;;; org-html-protect-char-alist
;;;; org-html-table-use-header-tags-for-first-column
;;;; org-html-todo-kwd-class-prefix
;;;; org-html-tag-class-prefix
;;;; org-html-footnote-separator

;;;; org-export-preferred-target-alist
;;;; org-export-solidify-link-text
;;;; class for anchors
;;;; org-export-with-section-numbers, body-only
;;;; org-export-mark-todo-in-toc

;;;; org-html-format-org-link
;;;; (caption (and caption (org-xml-encode-org-text caption)))
;;;; alt = (file-name-nondirectory path)

;;;;  org-export-time-stamp-file'

(provide 'ox-html)

;; Local variables:
;; generated-autoload-file: "org-loaddefs.el"
;; End:

;;; ox-html.el ends here
