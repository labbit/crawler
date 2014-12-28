package TextShow::Admin;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;


sub auth {
	my $self = shift;

	my $msg = $self->stash('mymessage');
	$self->stash(mymessage => 'Welcome');
}


sub login {
	my $self = shift;

	my $editor_login = 'editor';
	my $editor_passwd = 'superpass';

	my $login    = $self->param('login'); 
	my $password = $self->param('password');

	if (($login eq $editor_login) && ($password eq $editor_passwd)){
		$self->session(
			user_id => 99999,
			login   => $login
		)->redirect_to('/admin');
	} else {
		$self->flash( error => 'Wrong password or login user!' )->redirect_to('/form');
	}

}


sub logout {    
	shift->session( user_id => '', login => '' )->redirect_to('/form'); 
}

sub check {
	shift->session('user_id') ? 1 : 0; 
}



sub list {
	my $self = shift;

	my $list;
	my $sth = $self->app->dbconn->run(fixup => sub {        
		my $sth = $_->prepare(
			'SELECT 
				c.name AS cat, 
				a.article_id AS aid, LEFT(a.text, 60) AS text, 
				a.mtime, a.ctime
			FROM article AS a, category AS c 
			WHERE                 
				a.category_id = c.category_id
			ORDER BY a.mtime DESC');
		$sth->execute();
		$list = $sth->fetchall_hashref('ctime');
		$sth->finish();
	});
	$self->stash(articles => $list);
	
}


sub edit {
	my $self = shift;
	
	my $id = $self->stash('id');

	my $list; 	
	my $sth = $self->app->dbconn->run(fixup => sub {
		my $sth = $_->prepare("SELECT 
				article_id,
				category_id,
				text				
			FROM article
			WHERE 
				article_id = ?
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


	my $cats;
	my $sth_c = $self->app->dbconn->run(fixup => sub {
	my $sth_c = $_->prepare("SELECT 
				category_id AS c_id, name
			FROM category
			ORDER BY category_id ASC");
		$sth_c->execute();
		$cats = $sth_c->fetchall_hashref('c_id');
		$sth_c->finish();
	});


	$self->stash(
		msg => $list->{text}, 
		a_id => $list->{article_id}, 	
		c_id => $list->{category_id},
		mtime => $list->{mtime},
		cats => $cats,
		tags => $tags
	);
}




sub preview {
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


sub update {
	my $self = shift;

	my $id = $self->stash('id');

	my $category_id = $self->req->body_params->param('cat_id');
	my $text = $self->req->body_params->param('article');
	my $show_flag = $self->req->body_params->param('show_flag');

	if ( (int($id) != 0) && (int($category_id) != 0 ) && ($text ne '')) {

		eval {
			my $sth = $self->app->dbconn->run(fixup => sub {
			my $sth = $_->prepare("UPDATE article
					SET 
						mtime = NOW(), 
						text = ?,
					 	category_id = ?,
					 	status = ?
					WHERE 
						article_id = ?			
					LIMIT 1");
				$sth->execute($text, $category_id, $show_flag, $id);	
			});
		};
		if($@) {
			$self->render(text => 'DB ERROR:'.$@); 
			$self->flash( error => 'Something wrong to DB!' )->redirect_to('/admin');
		} else {
			$self->app->dbconn->dbh->commit;
			$self->redirect_to('/admin/'.$id.'/preview');
		}

		
	} else {
		$self->flash( error => 'Category or main tex section empty!' )->redirect_to('/admin/'.$id.'/edit');
	}

	


}


1;
