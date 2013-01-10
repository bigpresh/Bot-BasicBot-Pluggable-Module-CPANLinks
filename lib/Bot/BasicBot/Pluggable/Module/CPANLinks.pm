# A quick Bot::BasicBot::Pluggable module to provide easy links when someone
# mentions CPAN modules
# David Precious <davidp@preshweb.co.uk>

package Bot::BasicBot::Pluggable::Module::CPANLinks;
use strict;
use base 'Bot::BasicBot::Pluggable::Module';
use Module::Load;
use URI::Title;
use 5.010;

=head1 NAME

Bot::BasicBot::Pluggable::Module::CPANLinks - provide links to CPAN module docs

=head1 DESCRIPTION

A module for L<Bot::BasicBot::Pluggable>-powered IRC bots, to automatically
provide links to documentation when people mention certain CPAN modules or
keywords.  Can be configured to only respond to modules in certain namespaces on
a per-channel basis.

=head1 HOW IT WORKS

If someone's message looks like it contains a CPAN module name (e.g.
C<Foo::Bar>), this plugin will look for the bot setting
C<cpanlinks_filter_$channel> where C<$channel> is the channel that the user
spoke in - so, e.g. C<cpanlinks_filter_#dancer>.  If this setting exists, its
value should be a regular expression; if the module name matches this
expression, the plugin will look up that module, and, if it exists, provide a
link to it (unless it has done so more recently than the configurable
threshold).

Similarly, if someone says something like "the session keyword" or similar, the
plugin will check if C<cpanlinks_keywords_$channel> exists and is set to a
package name; if it does, it will make sure that package is loaded, check if
that package C<can($keyword)>, and if so, will provide a link to the
documentation for that keyword.

So, for example, in the C<#dancer> channel, C<cpanlinks_keywords_#dancer> would
be set to C<Dancer> - so if I say "the session keyword", the plugin will check
if C<Dancer->can('session')> to check it's a valid keyword, and if so, will
provide a link to the docs.

WARNING: this setting causes the named package to be loaded; that means that
anyone who can configure your bot from IRC can cause a package of their choosing
to be loaded into your bot.  It must be a package which is already installed on
your system, of course, but it deserves that warning.


=cut

sub help {
    return <<HELPMSG;
A quick plugin for use on IRC channels to provide links to module /
keyword documentation.

See the plugin's documentation on CPAN for full details and source: 
http://p3rl.org/Bot-BasicBot-Pluggable-Module-CPANLinks
HELPMSG
}

my %link_said;
sub said {
    my ($self, $mess, $pri) = @_;
    
    return unless $pri == 2;
    my $link;
    if (my ($module) = $mess->{body} =~ /\b((?:\w+::)+\w+)\b/) {
        warn "Think I have a module mention: " . $module;
        my $key = lc $mess->{channel};
        my $filter_pattern = $self->get("filter_" . lc $mess->{channel}) 
            or return 0;
        warn "Checking if this matches pattern $filter_pattern";
        return 0 unless $module =~ /$filter_pattern/i;

        # OK, this looks like a module name which matches the pattern for this
        # channel, awesome:
        my $url = "http://p3rl.org/$module";
        my $title = URI::Title::title($url);
        if ($title) {
            $title =~ s/^$module - //;
            $title =~ s/- metacpan.+//;
            $link = "$module is at http://p3rl.org/$module ($title)";
        }
    }


    # OK, if the message contains "the ... keyword" and the channel supports
    # keywords for a given module (e.g. Dancer), see if this is a valid keyword,
    # and if so, link to the docs for it
    if (my $keywords_from 
        = $self->get('cpanlinks_keywords_' . lc $mess->{channel}) 
        && $mess->{body} =~ m{
            (
            # match"the keyword forward", "the keyword 'forward", etc
            the \s keyword \s ['"]? (?<keyword> [a-z_-]+) ['"]?
            |
            # or "forward keyword, "'forward' keyword, "forward() keyword" etc
            \b['"]? (?<keyword> [a-z_-]+) ['"]? (?:\(\))? \s keyword
            )
        }xm
    ) {
        my $keyword = $+{keyword};
        warn "Mentioned keyword $keyword, checking it";
        Module::Load::load($keywords_from);

        if ($keywords_from->can($keyword)) {
            $link = "The $keyword keyword is documented at "
                . "http://p3rl.org/$keywords_from#$keyword";
        }
    }

    # Announce the link we found, unless we already did that recently
    if ($link && time - $link_said{$link} > 60) {
        $link_said{$link} = time;
        return $link;
    }

    return 0; # This message didn't interest us
}



=head1 AUTHOR

David Precious (bigpresh) C<< <davidp@preshweb.co.uk> >>

=cut
1;
