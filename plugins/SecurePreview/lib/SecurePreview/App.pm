package SecurePreview::App;

use strict;
use warnings;
use MT::CMS::Entry;

sub preview_entry_secure {
    my $app = shift;

    $app->validate_magic or return;

    my $entry = &MT::CMS::Entry::_create_temp_entry($app);

    my $q           = $app->param;
    my $type        = $q->param('_type') || 'entry';
    my $entry_class = $app->model($type);
    my $blog_id     = $q->param('blog_id');
    my $blog        = $app->blog;
    my $id          = $q->param('id');
    my $user_id     = $app->user->id;
    my $cat;
    my $cat_ids = $q->param('category_ids');

    if ($cat_ids) {
        my @cats = split /,/, $cat_ids;
        if (@cats) {
            my $primary_cat = $cats[0];
            $cat = MT::Category->load(
                { id => $primary_cat, blog_id => $blog_id } );
            my @categories
                = MT::Category->load( { id => \@cats, blog_id => $blog_id } );
            $entry->cache_property( 'category',   undef, $cat );
            $entry->cache_property( 'categories', undef, \@categories );
        }
    }
    else {
        $entry->cache_property( 'category', undef, undef );
        $entry->cache_property( 'categories', undef, [] );
    }
    my $tag_delim = chr( $app->user->entry_prefs->{tag_delim} );
    my @tag_names = MT::Tag->split( $tag_delim, $q->param('tags') );
    if (@tag_names) {
        my @tags;
        foreach my $tag_name (@tag_names) {
            my $tag = MT::Tag->new;
            $tag->name($tag_name);
            $tag->is_private( $tag_name =~ m/^@/ ? 1 : 0 );
            push @tags, $tag;
        }
        $entry->{__tags}        = \@tag_names;
        $entry->{__tag_objects} = \@tags;
    }

    my $ao_date = $q->param('authored_on_date');
    my $ao_time = $q->param('authored_on_time');
    my $ao_ts   = $ao_date . $ao_time;
    $ao_ts =~ s/\D//g;
    $entry->authored_on($ao_ts);

    my $uo_date = $q->param('unpublished_on_date');
    my $uo_time = $q->param('unpublished_on_time');
    my $uo_ts   = $uo_date . $uo_time;
    $uo_ts =~ s/\D//g;
    $entry->unpublished_on($uo_ts);

    my $preview_basename = $app->preview_object_basename;
    $entry->basename( $q->param('basename') || $preview_basename );

    # translates naughty words when PublishCharset is NOT UTF-8
    MT::Util::translate_naughty_words($entry);

    $entry->convert_breaks( scalar $q->param('convert_breaks') );

    my @data = ( { data_name => 'author_id', data_value => $user_id } );
    $app->run_callbacks( 'cms_pre_preview', $app, $entry, \@data );

    require MT::TemplateMap;
    require MT::Template;
    my $at = $type eq 'page' ? 'Page' : 'Individual';
    my $tmpl_map = MT::TemplateMap->load(
        {   archive_type => $at,
            is_preferred => 1,
            blog_id      => $blog_id,
        }
    );

    my $tmpl;
    my $fullscreen;
    my $archive_file;
    my $orig_file;
    my $file_ext;
    if ($tmpl_map) {
        $tmpl         = MT::Template->load( $tmpl_map->template_id );
        $file_ext     = $blog->file_extension || '';
        $archive_file = $entry->archive_file;

        my $blog_path
            = $type eq 'page'
            ? $blog->site_path
            : ( $blog->archive_path || $blog->site_path );
        $archive_file = File::Spec->catfile( $blog_path, $archive_file );
        require File::Basename;
        my $path;
        ( $orig_file, $path ) = File::Basename::fileparse($archive_file);
        $file_ext = '.' . $file_ext if $file_ext ne '';
        $archive_file
            = File::Spec->catfile( $path, $preview_basename . $file_ext );
    }
    else {
        $tmpl       = $app->load_tmpl('preview_entry_content.tmpl');
        $fullscreen = 1;
    }
    return $app->error( $app->translate('Cannot load template.') )
        unless $tmpl;

    my $ctx = $tmpl->context;
    $ctx->stash( 'entry',    $entry );
    $ctx->stash( 'blog',     $blog );
    $ctx->stash( 'category', $cat ) if $cat;
    $ctx->{current_timestamp}    = $ao_ts;
    $ctx->{current_archive_type} = $at;
    $ctx->var( 'preview_template', 1 );

    my $archiver = MT->publisher->archiver($at);
    if ( my $params = $archiver->template_params ) {
        $ctx->var( $_, $params->{$_} ) for keys %$params;
    }

    return $tmpl->output;
}


1;
