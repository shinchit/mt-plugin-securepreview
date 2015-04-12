package SecurePreview::Transformer;
use strict;

sub hdlr_template_output_edit_entry {
    my ($cb, $app, $tmpl_str_ref, $param, $tmpl) = @_;

    my $old = 'preview_entry';
    my $new = 'preview_entry_secure';
    $$tmpl_str_ref =~ s/$old/$new/g;
}

1;
