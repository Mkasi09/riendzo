import 'package:flutter/material.dart';

//Initializing the variables for the initial state for the password icon and visibility
bool passwordVisible = true;
IconData passwordVisibilityIcon = Icons.visibility;

// toggle the password view icon
 IconData togglePasswordIcon({passwordVisibilityIcon}) {
  if (passwordVisibilityIcon == false) {
    return Icons.visibility;
  } else {
    return Icons.visibility_off;
  }
}

//toggle the visibility of the password to dots or text
 bool togglePasswordView({passwordView}) {
  if (passwordView == false) {
    return true;
  } else {
   return false;
  }
}
