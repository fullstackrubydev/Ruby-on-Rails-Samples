class EventGuestListIndex < ActiveModelSerializers::Model
  attr_accessor :email,
                :userName,
                :fullName,
                :profileID,
                :rsvp,
                :action,
                :avatarThumb,
                :followers,
                :location,
                :connectionType,
                :profileConnectionToViewer,
                :viewerConnectionToProfile

end
