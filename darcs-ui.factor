USING: accessors arrays cocoa.dialogs closures continuations
darcs-ui.commands fry file-trees io io.files io.pathnames
io.directories io.encodings.utf8 kernel math models monads
sequences splitting ui ui.gadgets.alerts ui.frp.gadgets
ui.frp.layout ui.frp.signals ui.frp.instances
ui.gadgets.comboboxes ui.gadgets.labels ui.gadgets.scrollers
ui.baseline-alignment ui.images unicode.case ;
EXCLUDE: fries => _ ;
IN: darcs-ui
: <patch-viewer> ( columns -- scroller ) <frp-table>
   [ first ] >>val-quot t >>multiple-selection?
   { "Patch" "Author" "Date" } >>column-titles
   <scroller> ;

: <change-list> ( {str} -- gadget ) <frp-list> t >>multiple-selection? indexed <scroller> ;

: answer ( length indices -- ) [ index [ "y" ] [ "n" ] if write ] curry each flush ;

: patches-quot ( -- model-of-quot )
   [ whatsnew [ length <model> ] keep <model>
      [ <change-list> ->% 1 "okay" <frp-button> [ close-window ] >>hook
         -> <updates> [ [ answer ] 2curry ] 2fmap-&
      ] <vbox> { 229 200 } >>pref-dim "select changes" open-window
   ] [ drop [ ] "No changes!" alert f <model> ] recover ;

: <darcs-button> ( str -- button ) i" vocab:darcs-ui/icons/_.tiff" <image-name> <frp-button> ;
: <patch-button> ( str -- model ) <darcs-button> -> [ drop patches-quot ] bind ;

: load-pref ( name file -- model ) "_darcs/prefs/" prepend dup exists?
   [ utf8 [ readln ] with-file-reader <model> nip ]
   [ '[ dup _ utf8 set-file-contents ] swap ask-user swap fmap ] if ;

: toolbar ( -- file-updates patch-updates )
   "add" <darcs-button> -> [ drop open-dir-panel [ add-repo-file ] when* ] $>
   "rem" <darcs-button> -> [ drop open-panel [ remove-repo-file ] when* ] $>
      2array <merge> >behavior
   "rec" <patch-button> dup [ drop "Patch Name:" ask-user ] bind dup
      DIR[ drop "Your Name:" "author" load-pref ] bind DIR[ record ] 3$>-&
   "push" <darcs-button> -> [ "Push To:" "defaultrepo" load-pref ] bind* DIR[ repo-push ] $> ,
   "pull" <darcs-button> -> [ "Pull From:" "defaultrepo" load-pref ] bind* DIR[ pull ] $>
   "send" <darcs-button> -> [ "Send To:" "defaultrepo" load-pref ] bind* DIR[ send ] $> ,
   "app" <darcs-button> -> DIR[ open-dir-panel [ first app ] when* ] $> 3array <merge> >behavior ;

: darcs-window ( -- ) [
      [
          toolbar
          <spacer>
          { "PATCHES:" "MATCHES:"
            "FROM-TAG:" "FROM-PATCH:" "FROM-MATCH:"
            "TO-TAG:" "TO-MATCH:" "TO-PATCH:"
         } <combobox> -> [ but-last >lower ] fmap
         <frp-field> { 100 10 } >>pref-dim ->% 1
      ] <hbox> +baseline+ >>align ,
      [
         DIR[ rot drop patches ] 3fmap-| <patch-viewer> ->% .5 [ [ f ] when-empty ] fmap
         [ DIR[ drop files "\n" split create-tree ] fmap <dir-table> <scroller> ->% .5
           [ file? ] <filter> [ comment>> ] fmap
         ] dip
      ] <hbox> ,% .5 [
         [ length 1 = ] <filter> DIR[ first cnts ] 2fmap-|
         "Select a patch and file to see its historical contents" <model> swap <switch>
      ] [ [ length 2 = ] <filter> [ t <model> swap <switch> ] dip DIR[ first2 swap diff ] 2fmap-| ] 2bi
      2array <merge> <label-control> <scroller> ,% .5
   ] <vbox> "darcs" open-window ;

DEFER: open-file
: create-repo ( -- ) "The selected folder is not a darcs repo.  Would you like to create one?" { "get remote" "init local" "find another repo" } ask-buttons
   [ [ drop "Patch Name:" ask-user ] bind DIR[ dup repo-get file-name [ darcs-window ] with-directory ] $> activate-model ]
   [ DIR[ drop [ init-repo darcs-window ] [ drop "Can't write to folder" alert* ] recover ] $> activate-model ]
   [ [ drop open-file ] $> activate-model ] tri* ;

: open-file ( -- ) [ open-dir-panel
      [ first [ "_darcs" exists? [ darcs-window ] [ create-repo ] if ] with-directory ] unless-empty
   ] with-ui ;

MAIN: open-file