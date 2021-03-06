import 'package:chall/Globals/Strings.dart';
import 'package:chall/Globals/constants.dart';
import 'package:chall/Providerr/imageuploadprovider.dart';
import 'package:chall/Screens/chatscreens/widgets/cachedImage.dart';
import 'package:chall/Widgets/Appbar.dart';
import 'package:chall/Widgets/customtile.dart';
import 'package:chall/enumm/view_state.dart';
import 'package:chall/models/message.dart';
import 'package:chall/models/user.dart';
import 'package:chall/resources/firebase_repository.dart';
import 'package:chall/utils/call_utils.dart';
import 'package:chall/utils/permissions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker/emoji_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:chall/utils/utilities.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final UserClass receiver;

  const ChatScreen({Key key, this.receiver}) : super(key: key);
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController _textEditingController = TextEditingController();
  FirebaseRepository _firebaseRepository = FirebaseRepository();
  ScrollController _listScrollController = ScrollController();
  FocusNode textFieldFocus = FocusNode();
  bool isWriting = false;
  bool showEmojiPicker = false;
  ImageUploadProvider _imageUploadProvider;

  UserClass sender;
  String _currentUserId;



  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _firebaseRepository.getUserCurrentlyFutureMethod().then((user) {
      setState(() {
        _currentUserId = user.uid;
        sender = UserClass(
          uid: user.uid,
          name: user.displayName,
          profilePhoto: user.photoURL,

        );
      });
    }


    );

  }

  showKeyboard() => textFieldFocus.requestFocus();
  hideKeyboard() => textFieldFocus.unfocus();
  hideEmojiContainer(){
    setState(() {
      showEmojiPicker = false;
    });
  }
  showEmojiContainer(){
    setState(() {
      showEmojiPicker = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    _imageUploadProvider = Provider.of<ImageUploadProvider>(context);
    return Scaffold(
      backgroundColor: UniversalVariables.blackColor,
      appBar: customAppBar(context),
      body: Column(
        children: [

          Flexible(child: messageList()),
          _imageUploadProvider.getViewState == ViewState.LOADING ? Container(
              margin: EdgeInsets.only(right: 15),
              alignment: Alignment.centerRight,
              child: CircularProgressIndicator()) : Container(),

          chatControls(),
          showEmojiPicker ? Container(child: emojiContainer(),) : Container(),
        ],
      ),
    );
  }

  emojiContainer(){
    return EmojiPicker(
      bgColor: UniversalVariables.separatorColor,
      indicatorColor: UniversalVariables.blueColor,
      rows: 3,
      columns: 7,
      recommendKeywords: ["face","happy","party"],
      numRecommended: 30,
      onEmojiSelected: (emoji, category){
        setState(() {
          isWriting = true;
        });
        _textEditingController.text = _textEditingController.text + emoji.emoji;

      },
    );
  }
  Widget messageList(){
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection(Messages_Collection).doc(_currentUserId).collection(widget.receiver.uid).orderBy(TimeStamp_Data,descending: true).snapshots(),
      builder: (context,AsyncSnapshot<QuerySnapshot> snapshot){
        if(snapshot.data == null){
          return Center(child: CircularProgressIndicator(),);
        }
        //have an auto scroll on each message but you can use that using a button l
//        SchedulerBinding.instance.addPostFrameCallback((_) {
//          _listScrollController.animateTo(_listScrollController.position.minScrollExtent, duration: Duration(
//            milliseconds: 250
//          ), curve: Curves.easeOut);
//        });

        return ListView.builder(
          controller: _listScrollController,
          reverse: true,
            padding: EdgeInsets.all(10),
            itemCount: snapshot.data.docs.length,
            itemBuilder: (context,index){
              return chatMessageItem(snapshot.data.docs[index]);
            });
      },
    );
  }


  Widget chatMessageItem(QueryDocumentSnapshot snapshot){

    Message _message = Message.fromMap(snapshot.data());
    return Column(
      crossAxisAlignment: _message.senderId == _currentUserId ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(


          child: Container(


            child: _message.senderId == _currentUserId ? senderLayout(_message) : receiverLayout(_message),
          ),
        ),
      ],
    );
  }

  Widget senderLayout(Message message){
    Radius messageRdius = Radius.circular(10);

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),

      margin: EdgeInsets.only(top: 12),

    decoration: BoxDecoration(
        color: UniversalVariables.senderColor,
        borderRadius: BorderRadius.only(
            topLeft: messageRdius,topRight: messageRdius,bottomLeft: messageRdius
        )
    ),
      child: Padding(padding: EdgeInsets.all(10),
      child: getMessage(message)
      ),
    );


  }

  getMessage(Message message){
     if(message.type != 'image'){
       return Text(

         message != null ? message.message : "",
         style: TextStyle(
             color: Colors.white,
             fontSize: 16
         ),);
     }
     else{
       if(message.photoUrl == null){
         return Text("ERROR");
       }
       else{
         print(message.photoUrl);
         return CachedImage(Url:message.photoUrl,height: 250,width: 250,radius: 10,isRound: false,) ;
       }
     }

  }

  Widget receiverLayout(Message message){
    Radius messageRdius = Radius.circular(10);

    return Container(
      margin: EdgeInsets.only(top: 12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
          color: UniversalVariables.senderColor,
          borderRadius: BorderRadius.only(
              bottomRight: messageRdius,topRight: messageRdius,bottomLeft: messageRdius
          )
      ),
      child: Padding(padding: EdgeInsets.all(10),
        child: getMessage(message),
      ),
    );

  }

  Widget chatControls(){

    setWriting(bool writing){
      setState(() {
        isWriting = writing;
      });
    }

    executePhotoChoose()async {
      await pickImage(source: ImageSource.gallery);
    }

    addMediaModel(BuildContext context){
      return showModalBottomSheet(context: context,
          elevation: 0,
          backgroundColor: UniversalVariables.blackColor,


          builder: (context){
            return Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    children: [
                      FlatButton(onPressed: (){
                        Navigator.maybePop(context);
                      }
                      , child: Icon(Icons.close,color: Colors.white,)),
                      Expanded(child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Content & Tools',style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold
                        ),),
                      ),

                      ),

                    ],
                  ),
                ),
                Flexible(child: ListView(
                  children: [
                        ModalTile(
                          title: "Media",
                          subtitle: "Share Photos and Videos",
                          icon: Icons.image,
                          onPressed: executePhotoChoose,
                        ),
                    ModalTile(
                      title: "File",
                      subtitle: "Share Files",
                      icon: Icons.tab,
                    ),
                    ModalTile(
                      title: "Contact",
                      subtitle: "Share Contacts",
                      icon: Icons.contacts,
                    ),
                    ModalTile(
                      title: "Location",
                      subtitle: "Share a location",
                      icon: Icons.add_location,
                    ),
                    ModalTile(
                      title: "Schedule Call",
                      subtitle: "Arrange a call and get Reminders",
                      icon: Icons.schedule,
                    ),
                    ModalTile(
                      title: "Create Poll",
                      subtitle: "Share Polls",
                      icon: Icons.poll,
                    )
                  ],
                ))
              ],
            );
          });
    }
    return Container(
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          GestureDetector(
            onTap : () => addMediaModel(context),
            child: Container(
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                gradient: UniversalVariables.fabGradient,
                shape: BoxShape.circle
              ),
              child: Icon(Icons.add),
            ),
          ),
          SizedBox(
            width: 5,
          ),
          Expanded(child:
          Stack(
            children: [
              TextField(
                onTap: (){
                  hideEmojiContainer();
                },
                focusNode: textFieldFocus,
                controller: _textEditingController,
                style: TextStyle(
                  color: Colors.white
                ),
                onChanged: (val){
                  (val.length > 0 && val.trim() != "") ? setWriting(true) : setWriting(false);
                },
                decoration: InputDecoration(
                  hintText: "Type a Message",
                  hintStyle: TextStyle(
                    color: UniversalVariables.greyColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                    borderSide: BorderSide.none,

                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20,vertical: 5),
                  filled: true,
                  fillColor: UniversalVariables.separatorColor,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  onPressed: (){
                    if(!showEmojiPicker){
                      hideKeyboard();
                      showEmojiContainer();
                    }else{
                      showKeyboard();
                      hideEmojiContainer();
                    }
                  },
                  icon: Icon(Icons.face),

                ),
              )
            ],
          )),
          isWriting ? Container() : Padding(padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.record_voice_over,color: Colors.white,),

          ),
          isWriting ? Container() : GestureDetector(
              onTap: ()=> pickImage(source: ImageSource.camera),
              child: Icon(Icons.camera_alt,color: Colors.white,)),

          isWriting ? Container(
            margin: EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              gradient: UniversalVariables.fabGradient,
              shape:BoxShape.circle,

            ),
            child: IconButton(icon: Icon(Icons.send,size: 15,), onPressed: (){
                  sendMessage();
            }),

          ): Container(),

        ],
      ),
    );
  }

  sendMessage(){
    var text = _textEditingController.text;
    Message _message = Message(
      receiverId: widget.receiver.uid,
      senderId: sender.uid,
      message: text,
      timeStamp: Timestamp.now(),
      type: 'text'


    );

    setState(() {
      isWriting = false;
    });
    _textEditingController.text = "";

    _firebaseRepository.addMessageToDb(_message,sender,widget.receiver);
  }

  pickImage({@required  ImageSource source}) async{
   File selectedImage = await MyUtils.pickImage(source: source);
   _firebaseRepository.uploadImage(
     image: selectedImage,
     receiverId : widget.receiver.uid,
     senderId : _currentUserId,
     imageUploadProvider : _imageUploadProvider
   );


  }

  CustomAppBar customAppBar(BuildContext context){
    return CustomAppBar(
      leading: IconButton(icon: Icon(Icons.arrow_back), onPressed:(){
        Navigator.pop(context);
      }),
      centerTitle: false,
      title: Text(widget.receiver.name),
      actions: [
        IconButton(icon: Icon(Icons.video_call), onPressed: () {  CallUtils.dial(
            from: sender,
            to: widget.receiver,
            context: context
        );
        print('got here');}),
        IconButton(icon: Icon(Icons.phone), onPressed: (){

        }),

      ],
    );
  }
}

class ModalTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Function onPressed;
  const ModalTile({Key key, this.title, this.subtitle, this.icon, this.onPressed}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal:15.0),
      child: CustomTile(
        onTap: onPressed,
        mini: false,

        leading: Container(
          margin: EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: UniversalVariables.receiverColor,
          ),
          padding: EdgeInsets.all(10.0),
          child: Icon(icon,size: 38,color: UniversalVariables.greyColor,),

        ),
        subtitle: Text(subtitle,style: TextStyle(
          color: UniversalVariables.greyColor,
          fontSize: 14
        ),),
        title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18
          ),
        ),
      ),
    );
  }
}
