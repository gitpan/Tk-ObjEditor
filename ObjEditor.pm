package Tk::ObjEditor;

use Carp ;
use Tk::Derived ;
use Tk::Frame;
use Tk::ObjScanner;
use Tk::Dialog ;
use Tk::DialogBox ;
use strict;

use vars qw/$VERSION @ISA/;

use Storable qw(dclone);

@ISA = qw(Tk::Derived Tk::ObjScanner);
*isa = \&UNIVERSAL::isa;

$VERSION = sprintf "%d.%03d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/;

Tk::Widget->Construct('ObjEditor');

sub InitObject
  {
    my ($cw,$args) = @_ ;

    my $data  = delete $args->{'caller'} || delete $args->{'-caller'};
    $cw->{direct} =
      delete $args->{'direct'} || delete $args->{'-direct'} || 0 ;

    $cw->{user_data} = $data;

    my $edited_data = $cw->{direct} ? $data : dclone($data) ;

    $args->{'caller'} = $edited_data ; # to pass to ObjScanner

    $args->{title} = ref($data).' editor' unless 
      (defined $args->{title} || defined $args->{-title});

    $cw->SUPER::InitObject($args) ;

    unless ($cw->{direct})
      {
        $cw->{menu}->command( -label => 'reset',
                              -command => sub{$cw->reset});
      }

    $cw-> bind('<Button-3>', sub{$cw->modify_menu()}) ;

    $cw->{actions} = [];

    return $cw ;
  }

sub modify_menu
  {
    my $cw = shift;
    my $item = shift ; # reserved for tests

    unless (defined $item)
      {
        # pointery and rooty are common widget method and must called on
        # the right widget to give accurate results
        my $hlist=$cw->Subwidget('hlist');
        $item = $cw->nearest($hlist->pointery - $hlist->rooty) ;
      }

    $cw->selectionClear() ; # clear all
    $cw->selectionSet($item) ;
    #print "item $item to modify, button $b\n";

    my $menu = $cw->Menu;

    my $info = $cw->info("data",$item) ;
    my @children = $cw->infoChildren($item) ;

    if (not $cw->isPseudoHash($info) and 
        (isa($info,'ARRAY') or isa($info,'HASH')))
      {
        $menu -> add 
          (
           'command',
           '-label' => 'add element', 
           '-command' => sub {$cw->add_entry($item) ;}
          );
      }
    elsif (not ref($info))
      {
        $menu -> add 
          (
           'command',
           '-label' => 'modify element', 
           '-command' => sub {$cw->modify_entry($item) ;}
          );
      }

    $menu -> add 
      (
       'command',
       '-label' => 'delete', 
       '-command' => sub {$cw->delete_entry($item) ;}
      );

    $menu->Popup(-popover => 'cursor', -popanchor => 'nw');

    return $menu ;
  }

sub reset
  {
    my $cw = shift;

    $cw->{chief} = dclone($cw->{user_data});
    $cw->updateListBox();
  }

# returns the edited data (a clone in case of no-direct option)
sub get_data
  {
    my $cw = shift;

    return $cw->{chief};
  }

sub get_orig_data
  {
    my $cw = shift;

    return $cw->{user_data};
  }

sub modify_entry
  {
    my $cw = shift;
    my $item = shift ;
    my $is_text = shift || 0 ;

    my $text = $cw->entrycget($item,'-text');
    my ($item_key) = ($text =~ m/^[\[\{](.*?)[\]\}]->/);

    my $value= $cw->entrycget($item,'-data');

    $value=$cw->modify_widget($value, $is_text);
    
    return unless defined $value;

    # replace value in parent sdata structure
    my $parent_item = $cw->info("parent",$item);
    my $text_parent = $cw->entrycget($parent_item,"-text");
    
    my $parent_data = $text_parent =~ /^ROOT/ ? $cw->{chief}:
      $cw->entrycget($parent_item,'-data');

    if (isa($parent_data,'HASH') )
      {
        $parent_data->{$item_key}=$value
      }
    elsif (isa($parent_data,'ARRAY'))
      {
        $parent_data->[$item_key]=$value ;
      }
    elsif(isa($parent_data,'SCALAR'))
      {
        $$parent_data=$value;
      }
    else
      {
        die "Internal error: Cannot update value";
      }

    # update HList display
    $text =~ s/('.*')|(undefined)/\'$value\'/ ;
    $cw->entryconfigure($item,-text => $text);
    $cw->entryconfigure($item,-data => $value);
    }

sub modify_widget
  {
    my $cw = shift;
    my $value = shift ;
    my $is_text = shift ;

    # construct popup dialog to change item value.
    my $db = $cw->DialogBox(-title => 'modify element',
                            -buttons => ["OK", "Cancel"]) ;
    
    $db->add('Label', -text => 'Please enter new value')->pack;
    
    my $textw;
    if ($is_text or $value =~ /\n/)
      {
        $textw = $db->add('Text')->pack;
        $textw -> insert('end',$value) ;
        $db->bind('<Return>',''); # remove Dialog Box binding on return
      }
    else
      {
        $db->add('Entry',-textvariable => \$value)->pack;
      }

    my $answer = $db->Show ;

    return undef unless $answer eq "OK";

    $value = $textw->get('1.0','end') if defined $textw ;

    return $value;
  }

sub add_entry
  {
    my $cw = shift;
    my $item = shift ;

    # construct popup dialog to change item value.
    my $db = $cw->DialogBox(-title => 'add element',
                            -buttons => ["OK", "Cancel"]) ;

    my $ok = $db->Subwidget('B_OK');

    # enforce that a type is choosen by the user and that a new key is used
    my ($key_ok, $type_ok)=(0,0);
    my $check = sub {my $what = $key_ok && $type_ok ? 'normal': 'disabled';
                     $ok->configure(-state => $what);};

    &$check; # for fun and for test

    my $ref = $cw->entrycget($item,'-data');

    my $is_hash_like = isa($ref,'HASH');

    my $what = $is_hash_like ? 'key' : 'index' ;
    $db->add('Label', -text => "enter new $what")->pack;
    
    my $key = $is_hash_like ? '' : scalar(@$ref) ;

    $db->add('Entry',-textvariable => \$key,
             -validate => 'key',
             -validatecommand => sub
             {
               my $prop = shift;
               #print "key: '$prop'\n";
               if (($is_hash_like and not exists $ref->{$prop} ) or
                   (isa($ref,'ARRAY') and not defined $ref->[$prop] ))
                 {$key_ok =1 ;}
               else {$key_ok = 0;};
               &$check ;
               1;
             })->pack;

    $db->add('Label', -text => "Specify new element type")->pack;
    my $type = 'undef' ;
    my $mb = $db->add('Menubutton', -textvariable => \$type,
                      qw/-indicatoron 1 -relief raised/);
    
    my $menu = $mb->Menu(-tearoff => 0);
    $mb->configure(-menu => $menu);

    foreach (qw/array hash scalar text/)
      {
        $mb->radiobutton 
          (
           -label => $_, -value => $_, -variable => \$type,
           -indicatoron => 0, 
           -command => sub{$type_ok=1; &$check;}
          ) ;
      }

    $mb -> pack ;
    return if $db->Show ne 'OK' ;

    # update data structure
    my $new;
    if    ($type eq 'hash')  { $new = {} ;}
    elsif ($type eq 'array') { $new = [];}
    elsif ($type eq 'text')  { $new = $cw->modify_widget('',1);}
    else                     { $new = $cw->modify_widget('',0) ;}

    return unless defined $new ;

    $ref->{$key} = $new if isa($ref,'HASH') ;
    $ref->[$key] = $new if isa($ref,'ARRAY') ;

    #recompute the text for parent widget
    my $old = $cw->entrycget($item,'-text');
    my $save = $old =~ s/->.*// ? $old : '' ;
    my $text = $save. '-> '.$cw->element($ref);
    $cw->entryconfigure($item,'-text',$text);
    
    #(re)display the children
    $cw->deleteOffsprings($item);
    $cw->displaySubItem($item,$ref);

    }

sub delete_entry
  {
    my $cw = shift;
    my $item = shift ;

    my $text = $cw->entrycget($item,'-text');
    my ($item_key) = ($text =~ m/^[\[\{](.*?)[\]\}]->/);

    my $dialog = $cw->Dialog
      (
       -title => 'WARNING',
       -text => "Delete the '$item_key' element and all its children ?",
       -buttons => ["Yes","No"]
      );
    my $answer = $dialog->Show();

    return if $answer eq "No";

    
    my $parent_item = $cw->info("parent",$item);
    my $text_parent = $cw->entrycget($parent_item,"-text");
    
    my $parent;
    if ($text_parent !~ /^ROOT/)
      {
        chop $text_parent;
        my $counter = chop $text_parent;
        $counter--;
        $text_parent = $text_parent.$counter.")";
        $cw->entryconfigure($parent_item,"-text",$text_parent);
        $parent = $cw->entrycget($parent_item,'-data');
      }
    else
      {
        $parent = $cw->{chief};
      }

    delete $parent->{$item_key} if isa($parent, 'HASH') ;
    splice @$parent,$item_key,1  if isa($parent, 'ARRAY') ;

    $cw->deleteEntry($item);
  }


1;

__END__

=head1 NAME

Tk::ObjEditor - Tk composite widget Obj editor

=head1 SYNOPSIS

  use Tk::ObjEditor;
  
  my $editor = $mw->ObjEditor( caller => $object, 
                                direct => [1|0],
                                [title=>"windows"]) -> pack ;

=head1 DESCRIPTION

This widget provides a GUI to edit the attributes of an object or the
elements of a simple hash or array.

The editor is a L<Tk::ObjScanner> with additional function to edit data.

When the user double clicks (with left button) on an item, the
value of the item will be displayed in the HList.

If the value is a scalar, the scalar will be displayed in the text window.
(Which is handy if the value is a multi-line string)

Use the right button of the mouse of an element to modify its
value. Depending on the context, you will also be able to delete the
element or to add a sub-element.

This may be not clear. If yes, I think that trying this widget will be
much clearer than any explanation I can write. So run the Tk widget
demo and you'll find the Obj editor demo in the "User Contributed
Demonstration" section.

=head1 Direct or undirect edit

As the constructor will pass a reference to the data structure to be edited, the data can be edited :

=over

=item not directly

In this case, the data structure is cloned. The widget will edit the
cloned version of the data structure. This enable the user to cancel
the edition. This means that any reference to the internals of old
data structure will stay on the old datastructure and will not be
aware of the new values entered with this widget.

=item directly

In this case, the data structure is not cloned. The edition is performed on the
passed reference. Any reference to the internals of old
data structure will be updated on-line. The drawback is that the user cannot 
cancel (or undo) the edition.

=back

=head1 Constructor parameters

=over 4

=item *

caller: The ref of the object or hash or array to edit (mandatory).

=item *

title: the title of the menu created by the editor (optionnal)

=item *

direct: Set to 1 if you want to perform direct edition.

=back

=head1 CAVEATS

Like L<Tk::ObjScanner> ObjEditor does not detect recursive data
structures. It will just keep on displaying the tree until the user
gets tired of clicking on the HList items.

=head1 AUTHOR

Dominique Dumont, Guillaume Degremont.

Copyright (c) 1997-2001 Dominique Dumont, Guillaume Degremont. All
rights reserved.  This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1), L<Tk>, L<Tk::HList>, L<Tk::ObjScanner>

=cut


