package SortableWidget::Plugin;
use strict;

sub save_widget_order {
    my $app = shift;
    $app->validate_magic or return $app->trans_error( 'Permission denied.' );
    my $user = $app->user;
    my $widget_order = $app->param( 'widgets' );
    my $scope_type = $app->param( 'scope_type' );
    my $main_or_side = $app->param( 'scope' );
    my $scope = 'dashboard:';
    if ( $scope_type eq 'user' ) {
        $scope .= 'user:' . $user->id;
    } elsif ( $scope_type eq 'system' ) {
        $scope .= 'system';
    } else {
        if ( my $blog = $app->blog ) {
            $scope .= 'blog:' . $blog->id;
        } else {
            return 1;
        }
    }
    my $widgets = $user->widgets;
    my @order = split( /,/, $widget_order );
    my %widget_set;
    my $i = 1;
    for my $ord ( @order ) {
        $widget_set{ $ord } = { order => $i, set => $main_or_side };
        $i++;
    }
    my $old = $widgets->{ $scope };
    for my $w ( keys %$old ) {
        if (! grep( /^$w$/, @order ) ) {
            $widget_set{ $w } = $old->{ $w };
        }
    }
    $widgets->{ $scope } = \%widget_set;
    $user->widgets( $widgets );
    $user->save;
    return 1;
}

sub template_source {
    my ( $cb, $app, $tmpl ) = @_;
    my $user = $app->user;
    use Data::Dumper;
    warn Dumper $user->widgets;
    my $js = <<'JS';
<script type="text/javascript">
jQuery( function() {
    jQuery( '#widget-container-main' ).sortable( {
        items: 'div.widget',
        distance: 3,
        opacity: 0.8,
        containment: 'document',
        update: function () {
            update_widget( 'main' );
        }
    } );
    jQuery( '#widget-container-sidebar' ).sortable( {
        items: 'div.widget',
        distance: 3,
        opacity: 0.8,
        containment: 'document',
        update: function () {
            update_widget( 'sidebar' );
        }
    } );
} );
function update_widget( scope ) {
    var widget_order = new Array();
    var list = jQuery( '#widget-container-' + scope );
    var children = list.children();
    jQuery.each( children, function( i ) {
        if ( this.id ) {
            widget_order.push( this.id );
        }
    } );
    widgets = widget_order.join( ',' );
    var param = '__mode=save_widget_order'
      + '&blog_id=<mt:var name="blog_id">'
      + '&scope_type=<mt:var name="scope_type">'
      + '&scope=' + scope
      + '&widgets=' + widgets
      + '&magic_token=<mt:var name="magic_token">';
    var params = { uri: '<mt:var name="script_url">', method: 'POST', arguments: param };
    TC.Client.call( params );
}
</script>
JS
    my $pointer = quotemeta( '<mt:include name="include/footer.tmpl">' );
    $$tmpl =~ s/($pointer)/$js$1/;
}

1;