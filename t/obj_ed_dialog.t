# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..4\n"; }
END {print "not ok 1\n" unless $loaded;}
use Tk ;
use ExtUtils::testlib ; 
use Tk::ObjEditorDialog ;
use Tk::ROText ;
use Data::Dumper ;
$loaded = 1;
my $idx = 1;
print "ok ",$idx++,"\n";
my $trace = shift || 0 ;

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

package Toto ;

sub new
  {
    my $type = shift ;
    my $tkstuff = shift ;
    my $scalar = 'dummy scalar ref value';
    my $self = 
      {
       'key1' => 'value1',
       'array' => [qw/a b sdf/, {'v1' => '1', 'v2' => 2},'dfg'],
       'key2' => {
                  'sub key1' => 'sv1',
                  'sub key2' => 'sv2'
                 },
       'piped|key' => {a => 1 , b => 2},
       'scalar_ref_ref' => \\$scalar,
       'empty string' => '',
       'pseudo hash' => [ { a => 1, b => 2}, 'a value', 'bvalue'],
       'non_empty string' => ' ',
       'long' => 'very long line'.'.' x 80 ,
       'is undef' => undef,
       'some text' => "some \n dummy\n Text\n",
      } ;
    bless $self,$type;
  }


package main;

use strict ;
my $toto ;
my $mw = MainWindow-> new ;

print "creating dummy object \n" if $trace ;
my $dummy = new Toto ();

print "ok ",$idx++,"\n";


$mw->Label(text => "Here's the data that will be edited")->pack ;

my $text = $mw->Scrolled('ROText');
$text->pack;
$text->insert('end',  Dumper($dummy));

print "Creating some data monitors\n" if $trace ;

$mw->Label (text => "use right button to get editor menu")->pack;
my $fm = $mw ->Frame;
$fm -> pack;
$fm -> Label (text => 'Monitoring hash->{key1} value:')
  ->pack(qw/-side left/);
my $mon =
  $fm->Label(textvariable => \$dummy->{key1})->pack(qw/-side left/);

print "ok ",$idx++,"\n";

my $direct = sub
  {
    print "Creating obj editor (direct edition)\n" if $trace ;
    my $box = $mw -> ObjEditorDialog ('caller' => $dummy, direct => 1);

    $box -> Show;
    $text->delete('1.0','end');
    $text->insert('end',  Dumper($dummy));
  };

my $cloned = sub
  {
    print "Creating obj editor (not direct edition)\n" if $trace ;
    my $box = $mw -> ObjEditorDialog ('caller' => $dummy);
    my $new = $box -> Show;
    $text->delete('1.0','end');
    $text->insert('end',  Dumper($new));
  };

my $bf = $mw->Frame->pack;

### TBD edit direct and indirect ????

$bf->Button(-text => 'direct edit', command => $direct )
  ->pack(-side => 'right');
$bf->Button(-text => 'edit', command => $cloned )->pack(-side => 'right');
$bf->Button(-text => 'quit', command => sub{$mw->destroy;} )
  ->pack(-side => 'left');

MainLoop ; # Tk's

print "ok ",$idx++,"\n";

