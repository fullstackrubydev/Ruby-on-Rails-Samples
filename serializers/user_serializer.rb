class UserSerializer < ActiveModel::Serializer

  attributes :id,
             #:subscribers,         # from guest list
             :fullname,
             :displayname,
             :avatar,
             :accountVerified,
             :isFaceBookUser,
             :firstName,
             :lastName,
             :email,
             :hasLtToken,
             :hasAvatarUploaded,
             :hasCategorySelected,
             :isStaffMember
  attribute :fullName
  attribute :displayName

  def isStaffMember
    object.isStaffMember || false
  end
  def fullName
    object.firstName.to_s + '^' + object.lastName.to_s
  end
  def displayName
    object.displayname
  end
  def firstName
    (object.firstName.present?) ?
      object.firstName :
      ''
  end
  def lastName
    (object.lastName.present?) ?
      object.lastName :
      ''
  end
  def avatar
    {
      url: object.get_avatar,
      thumbURL: object.get_avatar_thumb
    }
  end

  def fullname
    object.firstName.to_s + '^' + object.lastName.to_s
  end

  def accountVerified
    object.status == 10 # verified if status is 10
  end

  def isFaceBookUser
    object.password_digest.blank? && object.status == 10
  end

  def hasAvatarUploaded
    object.avatar.present? || object.Avatar.present?
  end

  def hasCategorySelected
    object.user_interests.present?
  end

  def hasLtToken
    object.lt_token.present?
  end

end
