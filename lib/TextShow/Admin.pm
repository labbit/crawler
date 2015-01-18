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
				article_id AS aid, LEFT(text, 60) AS text, 
				status, mtime, ctime
			FROM article
			ORDER BY mtime DESC');
		$sth->execute();
		$list = $sth->fetchall_hashref('ctime');
		$sth->finish();
	});
	$self->stash(articles => $list, show_flag => $list->{status});
	
}


sub create {
	my $self = shift;

	my $new_text = 'new article';
	my $new_tag = 'new tag';


	my $r = $self->app->dbc->query('INSERT INTO article SET ctime = NOW(), mtime = NOW(), text = ?', $new_text);
	my ($text_id) = $self->app->dbc->query('SELECT article_id FROM article WHERE text = ? ORDER BY article_id DESC LIMIT 1', $new_text)->list;

	my $tag_id = $self->tag_new_save($new_tag);
	my @id = ($text_id, $tag_id);
	my $r = $self->tag_save(@id);

	my $edit_link = '/admin/' . $text_id . '/edit';	
	$self->redirect_to($edit_link);

}


sub hidden_text {
	my $self = shift;

	my $id = $self->stash('id');

	eval {
		my $sth = $self->app->dbconn->run(fixup => sub {
			my $sth = $_->prepare("UPDATE article
				SET 
					mtime = NOW(), 
					status = 0
				WHERE 
					article_id = ?
				LIMIT 1");
			$sth->execute($id);
		});
	};

	if($@) {
		$self->render(text => 'DB ERROR:'.$@); 
		$self->flash( error => 'Something wrong to DB!' )->redirect_to('/admin');
	} else {
		$self->app->dbconn->dbh->commit;
		$self->redirect_to('/admin/');
	}
	
}



sub show_text {
	my $self = shift;

	my $id = $self->stash('id');

	eval {
		my $sth = $self->app->dbconn->run(fixup => sub {
			my $sth = $_->prepare("UPDATE article
				SET 
					mtime = NOW(), 
					status = 1
				WHERE 
					article_id = ?
				LIMIT 1");
			$sth->execute($id);
		});
	};

	if($@) {
		$self->render(text => 'DB ERROR:'.$@); 
		$self->flash( error => 'Something wrong to DB!' )->redirect_to('/admin');
	} else {
		$self->app->dbconn->dbh->commit;
		$self->redirect_to('/admin/');
	}
	
}




sub edit {
	my $self = shift;
	
	my $id = $self->stash('id');

	my $list; 	
	my $sth = $self->app->dbconn->run(fixup => sub {
		my $sth = $_->prepare("SELECT 
				article_id,
				text				
			FROM article
			WHERE 
				article_id = ?
			LIMIT 1");
		$sth->execute($id);
		$list = $sth->fetchrow_hashref;
		$sth->finish();
	});

	my $tags; my $tag_list;
	my $sth_t = $self->app->dbconn->run(fixup => sub {
		my $sth_t = $_->prepare("SELECT 
				t.name
			FROM text_tag AS tt 
				LEFT JOIN tag AS t ON (tt.tag_id = t.tag_id)
			WHERE 
				tt.text_id = ?");
		$sth_t->execute($id);
		$tags = $sth_t->fetchall_arrayref;
		$sth_t->finish();		
	});
	if (scalar(@{$tags}) != 0) {
		$tag_list = join(', ', map { $_->[0] } @{$tags});
	} else {
		$tag_list = '';
	}

	$self->stash(
		msg => $list->{text}, 
		a_id => $list->{article_id}, 	
		mtime => $list->{mtime},
		tags => $tag_list
	);
}




sub preview {
	my $self = shift;

	my $id = $self->stash('id');
	
	my $list; 	
	my $sth = $self->app->dbconn->run(fixup => sub {
		my $sth = $_->prepare("SELECT 				
				a.article_id AS art_id, 
				a.text AS text, a.mtime	
			FROM article AS a
			WHERE 
				a.article_id = ?				
			LIMIT 1");
		$sth->execute($id);
		$list = $sth->fetchrow_hashref;
		$sth->finish();
	});

	my $tags; my $tag_list;
	my $sth_t = $self->app->dbconn->run(fixup => sub {
	my $sth_t = $_->prepare("SELECT 
				t.name
			FROM text_tag AS tt 
				LEFT JOIN tag AS t ON (tt.tag_id = t.tag_id)
			WHERE 
				tt.text_id = ?");
		$sth_t->execute($id);
		$tags = $sth_t->fetchall_arrayref;
		$sth_t->finish();
	});
	if (scalar(@{$tags}) != 0) {
		$tag_list = join(', ', map { $_->[0] } @{$tags});
	} else {
		$tag_list = '';
	}

	$self->stash(
		msg => $list->{text}, 
		art_id => $list->{art_id}, 	
		category => $list->{category}, 
		mtime => $list->{mtime},
		tags => $tag_list
	);

}


sub update {
	my $self = shift;

	my $id = $self->stash('id');
	
	my $text = $self->req->body_params->param('article');
	my $show_flag = $self->req->body_params->param('show_flag');
	my $tags = $self->req->body_params->param('tags');

	if ( (int($id) != 0) && ($text ne '')) {

		eval {
			my $sth = $self->app->dbconn->run(fixup => sub {
				my $sth = $_->prepare("UPDATE article
					SET 
						mtime = NOW(), 
						text = ?,
					 	status = ?
					WHERE 
						article_id = ?			
					LIMIT 1");
				$sth->execute($text, $show_flag, $id);
			});
		};

		if ($tags ne '') {

			my @tags = split(/\,\s?/, lc($tags));
			if (scalar(@tags) != 0) {

				my $r = $self->app->dbc->query('DELETE FROM text_tag WHERE text_id = ?', $id);
		
				foreach my $t (@tags) {

					my $tag_id = $self->tag_check($t);
					if (int($tag_id) == 0) {
						$tag_id = $self->tag_new_save($t);
					}
					my @id = ($id, $tag_id);
					my $r = $self->tag_save(@id);

				}			
				
			}
		}

		if($@) {
			$self->render(text => 'DB ERROR:'.$@); 
			$self->flash( error => 'Something wrong to DB!' )->redirect_to('/admin');
		} else {
			$self->app->dbconn->dbh->commit;
			$self->redirect_to('/admin/'.$id.'/preview');
		}
	
	} else {
		$self->flash( error => 'Category or main text section empty!' )->redirect_to('/admin/'.$id.'/edit');
	}




}



sub tag_check {
	my $self = shift;
	my $tag_name = shift;

    my ($tag_id) = $self->app->dbc->query('SELECT tag_id FROM tag WHERE name = ? LIMIT 1', $tag_name)->list;
	if ( defined $tag_id) {
		return $tag_id;
	} else {
		return 0;
	}
}



sub tag_save {
	my $self = shift;
	my @id = @_;

	my $r = $self->app->dbc->query('INSERT INTO text_tag SET text_id = ?, tag_id =?', @id);

	return 1;
}



sub tag_new_save {
	my $self = shift;
	my $tag_name = shift;

	my $r = $self->app->dbc->query('INSERT INTO tag SET name = ?', $tag_name);
	my ($tag_id) = $self->app->dbc->query('SELECT tag_id FROM tag WHERE name = ? LIMIT 1', $tag_name)->list;

	return $tag_id;
}


1;
