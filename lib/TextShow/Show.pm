package TextShow::Show;
use Mojo::Base 'Mojolicious::Controller';

sub taglist {
	my $self = shift;
	
	my $tag = $self->stash('tag');

	my $list;
	my $sth = $self->app->dbconn->run(fixup => sub {
	
	my $sth = $_->prepare('SELECT DISTINCT
				a.article_id, a.mtime,
				c.name AS cat, 
				LEFT(a.text, 60) AS text
			FROM
				tag AS t
				LEFT JOIN text_tag AS tt ON (t.tag_id = tt.tag_id)
				LEFT JOIN article AS a ON (tt.text_id = a.article_id)
				LEFT JOIN category AS c ON (a.category_id = c.category_id)
			WHERE
				t.name = ?
			ORDER BY a.mtime DESC');
		$sth->execute($tag);
		$list = $sth->fetchall_hashref('article_id');
		$sth->finish();
	});
	$self->stash(articles => $list);

}


sub someone {
	my $self = shift;
	
	my $id = $self->stash('id');

	my $list; 	
	my $sth = $self->app->dbconn->run(fixup => sub {
		my $sth = $_->prepare("SELECT 
				c.name AS category, 
				a.article_id AS art_id, 
				a.text AS text, a.mtime	
			FROM article AS a
				LEFT JOIN category AS c ON (a.category_id = c.category_id)
			WHERE 
				a.article_id = ?
				AND a.status != 0
			LIMIT 1");
		$sth->execute($id);
		$list = $sth->fetchrow_hashref;
		$sth->finish();
	});

	my $tags;
	my $sth_t = $self->app->dbconn->run(fixup => sub {
	my $sth_t = $_->prepare("SELECT 
				t.tag_id, t.name
			FROM text_tag AS tt 
				LEFT JOIN tag AS t ON (tt.tag_id = t.tag_id)
			WHERE 
				tt.text_id = ?");
		$sth_t->execute($id);
		$tags = $sth_t->fetchall_hashref('tag_id');
		$sth_t->finish();
	});

	$self->stash(
		msg => $list->{text}, 
		art_id => $list->{art_id}, 	
		category => $list->{category}, 
		mtime => $list->{mtime},
		tags => $tags
	);
}




sub all {
	my $self = shift;

	my $list;
	my $sth = $self->app->dbconn->run(fixup => sub {
		my $sth = $_->prepare("SELECT 
				c.name AS cat, 
				a.article_id AS aid, LEFT(a.text, 60) AS text, 
				a.mtime, a.ctime
			FROM article AS a, category AS c
			WHERE 
				a.status != 0 
				AND a.category_id = c.category_id
			ORDER BY a.mtime DESC");
		$sth->execute();
		$list = $sth->fetchall_hashref('ctime');
		$sth->finish();
	});
	$self->stash(articles => $list);
	
}



1;
