#!/usr/bin/ruby
#
# This file contians the class definition for the Task class.
#
# == Subversion ID
# 
# $Id$
# 
# == Authors
# 
# * Martin Chase <mchase@freegeek.org>
# 

require 'fgdb/work'

class FGDB::Task < FGDB::Work

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# SVN URL
	SVNURL = %q$URL$

	addAttributes( *%w[ type contact date ] )

	addAttributesReadOnly( *%w[ created modified ] )

	addAttributes( "hours" ) {|value|
		value and value.respond_to?(:to_f) and value.to_f >= 0
	}

end # class FGDB::Task
