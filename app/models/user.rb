class User < ActiveRecord::Base
  acts_as_userstamp
  has_and_belongs_to_many "roles"

  # Virtual attribute for the unencrypted password
  attr_accessor :password

  validates_presence_of     :login, :email
  validates_presence_of     :password,                   :if => :password_required?
  validates_presence_of     :password_confirmation,      :if => :password_required?
  validates_length_of       :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_length_of       :login,    :within => 3..40
  validates_length_of       :email,    :within => 3..100
  validates_uniqueness_of   :login, :email, :case_sensitive => false
  validates_uniqueness_of   :cashier_code
  before_save :encrypt_password
  before_save :add_cashier_code

  belongs_to :contact

  ####################################################
  # I HAVE NO IDEA WHAT THIS IS HERE FOR, BUT IF YOU #
  # FORGET ABOUT IT YOU WILL SPEND AN HOUR TRYING TO #
  # FIGURE OUT WHAT YOU DID WRONG                    #
  ####################################################
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :password, :password_confirmation, :can_login

  def self.reset_all_cashier_codes
    self.find(:all).each{|x|
      x.reset_cashier_code
      x.save
    }
  end

  def add_cashier_code
    reset_cashier_code if cashier_code.nil?
  end

  def reset_cashier_code
    valid_codes = (1000..9999).to_a - User.find(:all).collect{|x| x.cashier_code}
    my_code = valid_codes[rand(valid_codes.length)]
    self.cashier_code = my_code
  end

  def merge_in(other)
    for i in [:actions, :donations, :sales, :types, :users, :volunteer_tasks, :contacts, :gizmo_returns]
      User.connection.execute("UPDATE #{i.to_s} SET created_by = #{self.id} WHERE created_by = #{other.id}")
      User.connection.execute("UPDATE #{i.to_s} SET updated_by = #{self.id} WHERE updated_by = #{other.id}")
    end
    ["donations", "sales", "volunteer_tasks", "disbursements", "recyclings", "contacts"].each{|x|
      User.connection.execute("UPDATE #{x.to_s} SET cashier_created_by = #{self.id} WHERE cashier_created_by = #{other.id}")
      User.connection.execute("UPDATE #{x.to_s} SET cashier_updated_by = #{self.id} WHERE cashier_updated_by = #{other.id}")
    }
    self.roles = (self.roles + other.roles).uniq
    self.save!
  end

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, password)
    u = find_by_login(login) # need to get the salt
    return u if u && u.can_login && u.authenticated?(password)
    return nil
  end

  # Encrypts some data with the salt.
  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 2.weeks
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
  end

  # start auth junk

  def User.current_user
    Thread.current['user'] || User.fake_new
  end

  attr_accessor :fake_logged_in

  def User.fake_new
    u = User.new
    u.fake_logged_in = true
    u
  end

  def logged_in
    ! fake_logged_in
  end

  def User.has_privileges(*privs)
    User.current_user.has_privileges(*privs)
  end

  def to_privileges
    return "logged_in" if self.logged_in
  end

  def privileges
    @privileges ||= _privileges
  end

  def _privileges
    olda = []
    a = [self, self.contact, self.contact ? self.contact.worker : nil, self.roles].flatten.select{|x| !x.nil?}.map{|x| x.to_privileges}.flatten.select{|x| !x.nil?}.map{|x| Privilege.by_name(x)}
    while olda != a
      olda = a.dup
      a << olda.map{|x| x.children}.flatten
      a = a.flatten.sort_by(&:name).uniq
    end
    a = a.map{|x| x.name}
    a
  end

  def has_privileges(*privs)
    privs << "role_admin"
    privs.flatten!
    (privs & self.privileges).length > 0
  end

  # end auth junk

  protected
  # before filter
  def encrypt_password
    return if password.blank?
    self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
    self.crypted_password = encrypt(password)
  end

  def password_required?
    crypted_password.blank? || !password.blank?
  end

end
