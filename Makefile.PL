use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile
  (
   'NAME'	=> 'Tk::ObjEditor',
   'VERSION' => '2.001',
   'dist' => {COMPRESS=>'gzip -9f', SUFFIX => 'gz'},
   'PM' =>
   {
    'ObjEditor.pm'   => '$(INST_LIB)/Tk/ObjEditor.pm',
    'ObjEditorDialog.pm'   => '$(INST_LIB)/Tk/ObjEditorDialog.pm',
    'demo/obj_ed.pl' => '$(INST_ARCHLIB)/Tk/demos/widtrib/obj_ed.pl'
   },
   ($] >= 5.005 ?
    (ABSTRACT   => 'PTk widget to edit object or data',
     AUTHOR     => 'Dominique Dumont (domi@barrayar.grenoble.hp.com)') : ()),
   'PREREQ_PM' =>
   {
    'Tk' => 0,
    'Storable' => 0,
    'Tk::ObjScanner' => 2.001 ,
    'Data::Dumper' => 0
   }
  );
