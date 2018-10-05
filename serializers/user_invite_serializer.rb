class UserInviteSerializer < ActiveModel::Serializer

  attribute :id, key: :avUserID
  attribute :username, key: :userName
  attribute :firstName, key: :fName
  attribute :lastName, key: :lName
  attribute :zipcode, key: :zipCode
  attribute :email, key: :email
  attribute :type, key: :userType
  attribute :id, key: :profileID

  attribute :phone, key: :phone
  attribute :address, key: :address
  attribute :city, key: :city
  attribute :state, key: :state
  attribute :business_name, key: :businessName
end
