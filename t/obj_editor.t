# -*- cperl -*-
# Before `make install' is performed this script should be runnable with
use warnings FATAL => qw(all);
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..4\n"; }
END {print "not ok 1\n" unless $loaded;}
use Tk ;
use ExtUtils::testlib ; 
use Tk::ObjEditor ;
$loaded = 1;
my $idx = 1;
print "ok ",$idx++,"\n";
my $trace = shift || 0 ;

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):
package myHash;
use Tie::Hash ;
use vars qw/@ISA/;

@ISA=qw/Tie::StdHash/ ;

sub TIEHASH {
  my $class = shift; 
  my %args = @_ ;
  return bless { %args, dummy => 'foo' } , $class ;
}


sub STORE 
  { 
    my ($self, $idx, $value) = @_ ; 
    $self->{$idx}=$value;
    return $value;
  }

package MyScalar;
use Tie::Scalar ;
use vars qw/@ISA/;

@ISA=qw/Tie::StdHash/ ;

sub TIESCALAR {
  my $class = shift; 
  my %args = @_ ;
  return bless { %args, dummy => 'foo default value' } , $class ;
}


sub STORE 
  { 
    my ($self, $value) = @_ ; 
    $self->{data} = $value;
    return $value;
  }

sub FETCH
  {
    my ($self) = @_ ; 
    # print "\t\t",'@.....@.....@..... MeScalar read',"\n";
    return $self->{data} || $self->{dummy} ;
  }

package Toto ;

sub new
  {
    my %h ;
    tie %h, 'myHash', 'dummy key' => 'dummy value' or die ;
    $h{data1}='value1';

    my $type = shift ;
    my $tkstuff = shift ;
    my $scalar = 'dummy scalar ref value';
    my $self = 
      {
       'key1' => 'example of value for key1',
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
       'tied hash' => \%h
      } ;

    tie ($self->{tied_scalar}, 'MyScalar', 'dummy key' => 'dummy value')
      or die ;

    $self->{tied_scalar} = 'some scalar huh?';

    bless $self,$type;
  }


package main;

use strict ;
my $toto ;
my $mw = MainWindow-> new ;

my $w_menu = $mw->Frame(-relief => 'raised', -borderwidth => 2);
$w_menu->pack(-fill => 'x');

my $f = $w_menu->Menubutton(-text => 'File', -underline => 0) 
  -> pack(-side => 'left' );
$f->command(-label => 'Quit',  -command => sub{$mw->destroy;} );

print "creating dummy object \n" if $trace ;
my $dummy = new Toto ($mw);

print "ok ",$idx++,"\n";

print "Creating some obj monitors\n" if $trace ;

$mw->Label (-text => "use right button to get editor menu")->pack;
my $fm = $mw ->Frame;
$fm -> pack;
$fm -> Label (-text => 'Monitoring hash->{key1} value:')
  ->pack(qw/-side left/);
my $mon =
  $fm->Label(-textvariable => \$dummy->{key1})->pack(qw/-side left/);

print "Creating obj editor\n" if $trace ;
my $objEd = $mw -> ObjEditor
  (
   '-caller' => $dummy,
   -direct => 1 ,
   #destroyable => 0,
   -title => 'test editor'
  )
  -> pack(-expand => 1, -fill => 'both') ;

$mw->idletasks;
print "ok ",$idx++,"\n";

sub scan
  {
    my $topName = shift ;
    $objEd->yview($topName) ;

    foreach my $c ($objEd->infoChildren($topName))
      {
        $objEd->displaySubItem($c);
        scan($c);
	#print $c,"\n";
	last if $c =~ /root\|2/ ;
      }
    $mw->idletasks;
  }

sub refresh
    {
	$mw->idletasks;
	$mw->after(1000); # sleep 300ms
    }

if ($trace)
  {
    MainLoop ; # Tk's
  }
else
  {
    scan('root');
    $objEd->displaySubItem('root|1');


    # modify string entry
    my $menu = $objEd->modify_menu('root|1') ; # string entry
    refresh ;


    # since call to Dialog is blocking, we must pass this sub ref to a
    # timer
    my $sub = sub { 
	my $dialog = $objEd->get_current_dialog ;
	$dialog->Subwidget('Entry')->insert(0,'yada') ;
	refresh ;
	$dialog->Subwidget('B_OK')->invoke ;
    } ;
    $mw->after(1000,$sub) ;

    # Invoked Dialog will block until B_OK is pressed
    $menu->invoke(1) ;
    refresh ;

  }

print "ok ",$idx++,"\n";

