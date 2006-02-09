use ExtUtils::MakeMaker;

WriteMakefile(
				NAME			=> 'WWW::Search::PubMed',
				VERSION_FROM	=> 'lib/WWW/Search/PubMed.pm',
				AUTHOR			=> 'Gregory Williams <gwilliams@cpan.org>',
				PREREQ_PM		=> {
									'WWW::Search'		=> 0,
									'LWP::UserAgent'	=> 0,
									'XML::DOM'			=> 0
								},
			);
