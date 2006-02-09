package WWW::Search::PubMed;

=head1 NAME

WWW::Search::PubMed - Search the NCBI PubMed abstract database

=head1 SYNOPSIS

 use WWW::Search;
 my $s = new WWW::Search ('PubMed');
 $s->native_query( 'ACGT' );
 while (my $r = $s->next_result) {
  print $r->title . "\n";
  print $r->description . "\n";
 }

=head1 DESCRIPTION

WWW::Search::PubMed proivides a WWW::Search backend for searching the
NCBI/PubMed abstracts database.

=head1 VERSION

This document describes WWW::Search::PubMed version 1.1.0,
released 9 February 2006.

=head1 REQUIRES

 L<WWW::Search|WWW::Search>
 L<XML::DOM|XML::DOM>

=cut

our($VERSION)	= '1.001';

use strict;
use warnings;

require WWW::Search;
require WWW::SearchResult;
use base qw(WWW::Search);

use XML::DOM;
our $debug				= 0;

use constant	ARTICLES_PER_REQUEST	=> 20;
use constant	QUERY_ARTICLE_LIST_URI	=> 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmax=500';	# term=ACTG
use constant	QUERY_ARTICLE_INFO_URI	=> 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed';	# &id=12167276&retmode=xml

sub native_setup_search {
	my $self	= shift;
	my $query	= shift;
	my $options	= shift;
	
	$self->user_agent( "WWW::Search::PubMed/${VERSION} libwww-perl/${LWP::VERSION}; <http://kasei.us/code/pubmed/>" );
	
	my $ua			= $self->user_agent();
	my $url			= QUERY_ARTICLE_LIST_URI . '&term=' . WWW::Search::escape_query($query);
	my $response	= $ua->get( $url );
	my $success		= $response->is_success;
	if ($success) {
		my $parser	= new XML::DOM::Parser;
		my $content	= $response->content;
		$self->{'_xml_parser'}	= $parser;
		my $doc	= $parser->parse( $content );
		
		$self->{'_count'}	= eval { ($doc->getElementsByTagName('Count')->item(0)->getChildNodes)[0]->getNodeValue() } || 0;
		
		my @articles;
		my $ids	= $doc->getElementsByTagName('Id');
		my $n	= $ids->getLength;
		foreach my $i (0 .. $n - 1) {
			my $node		= $ids->item( $i );
			my @children	= $node->getChildNodes();
			push(@articles, + $children[0]->getNodeValue() );
		}
		$self->{'_article_ids'}	= \@articles;
	} else {
		return undef;
	}
}

sub native_retrieve_some {
	my $self	= shift;
	
	return undef unless scalar (@{ $self->{'_article_ids'} });
	my $ua			= $self->user_agent();
	my $url			= QUERY_ARTICLE_INFO_URI . '&id=' . join(',', splice(@{ $self->{'_article_ids'} },0,ARTICLES_PER_REQUEST)) . '&retmode=xml';
	warn 'Fetching URL: ' . $url if ($debug);
	my $response	= $ua->get( $url );
	if ($response->is_success) {
		my $content	= $response->content;
		if ($debug) {
			open (my $fh, ">/tmp/pubmed.article.info");
			print { $fh } $content;
			close($fh);
			warn "Saved response in /tmp/pubmed.article.info\n";
		}
		my $doc			= $self->{'_xml_parser'}->parse( $content );
		my $articles	= $doc->getElementsByTagName('PubmedArticle');
		my $n			= $articles->getLength;
		warn "$n articles found\n" if ($debug);
		my $count		= 0;
		foreach my $i (0 .. $n - 1) {
			my $article	= $articles->item( $i );
			my $id		= ($article->getElementsByTagName('PMID')->item(0)->getChildNodes)[0]->getNodeValue();
			warn "$id\n" if ($debug);
			my $title	= ($article->getElementsByTagName('ArticleTitle')->item(0)->getChildNodes)[0]->getNodeValue();
			warn "\t$title\n" if ($debug);
			my $url		= 'http://www.ncbi.nlm.nih.gov:80/entrez/query.fcgi?cmd=Retrieve&db=PubMed&list_uids=' . $id . '&dopt=Abstract';
			my @authors;
			my $authornodes	= $article->getElementsByTagName('Author');
			my $n		= $authornodes->getLength;
			foreach my $i (0 .. $n - 1) {
				my ($author, $fname, $lname);
				eval {
					$author	= $authornodes->item($i);
					$lname	= ($author->getElementsByTagName('LastName')->item(0)->getChildNodes)[0]->getNodeValue();
					$fname	= substr( ($author->getElementsByTagName('ForeName')->item(0)->getChildNodes)[0]->getNodeValue(), 0, 1) . '.';
				};
				if ($@) {
					warn $@ if ($debug);
					next unless ($lname);
				} else {
					push(@authors, join(' ', $lname, $fname));
				}
			}
			my $author	= join(', ', @authors);
			warn "\t$author\n" if ($debug);
			my ($journal, $page, $volume, $issue, $date, @date);
			eval {
				$journal	= ($article->getElementsByTagName('MedlineTA')->item(0)->getChildNodes)[0]->getNodeValue();
				$page		= ($article->getElementsByTagName('MedlinePgn')->item(0)->getChildNodes)[0]->getNodeValue();
				$volume		= ($article->getElementsByTagName('Volume')->item(0)->getChildNodes)[0]->getNodeValue();
				$issue		= ($article->getElementsByTagName('Issue')->item(0)->getChildNodes)[0]->getNodeValue();
				$date		= $article->getElementsByTagName('PubDate')->item(0);
				eval {
					my $year	= ($date->getElementsByTagName('Year')->item(0)->getChildNodes)[0]->getNodeValue();
					push(@date, $year);
					my $month	= ($date->getElementsByTagName('Month')->item(0)->getChildNodes)[0]->getNodeValue();
					push(@date, $month);
					my $day		= ($date->getElementsByTagName('Day')->item(0)->getChildNodes)[0]->getNodeValue();
					push(@date, $day);
				};
			};
			
			my $source	= '';
			if ($@) {
				warn $@ if ($debug);
				next unless ($journal);
			} else {
				my $date	= join(' ', grep defined, @date);
				$source	= "${journal}. "
						. ($date ? "${date}; " : '')
						. "${volume}"
						. ($issue ? "(${issue})" : '')
						. ($page ? ":$page" : '');
				$source	= "(${source})" if ($source);
			}
			warn "\t$source\n" if ($debug);
			
			my $hit		= new WWW::SearchResult;
			$hit->add_url( $url );
			$hit->title( $title );
			
			my $desc	= join(' ', grep {$_} ($author, $source));
			$hit->description( $desc );
			push( @{ $self->{'cache'} }, $hit );
			$count++;
			warn "$count : $title\n" if ($debug);
		}
		return $count;
	} else {
		warn "Uh-oh." . $response->error_as_HTML();
		return undef;
	}
	
}

1;

__END__

=head1 SEE ALSO

L<http://www.ncbi.nlm.nih.gov:80/entrez/query/static/overview.html>
L<http://eutils.ncbi.nlm.nih.gov/entrez/query/static/esearch_help.html>
L<http://eutils.ncbi.nlm.nih.gov/entrez/query/static/efetchlit_help.html>

=head1 COPYRIGHT

Copyright (c) 2003-2006 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=cut
