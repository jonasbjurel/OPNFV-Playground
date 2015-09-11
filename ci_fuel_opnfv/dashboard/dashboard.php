<!--#########################################################################-->
<!--# Copyright (c) 2015 Jonas Bjurel and others.                            -->
<!--# jonasbjurel@hotmail.com                                                -->
<!--# All rights reserved. This program and the accompanying materials       -->
<!--# are made available under the terms of the Apache License, Version 2.0  -->
<!--# which accompanies this distribution, and is available at               -->
<!--# http://www.apache.org/licenses/LICENSE-2.0                             -->
<!--#########################################################################-->

<html>
  <head>
    <title> OPNFV CI Dashboard </title>
<link rel="stylesheet" type="text/css" href="dash-stylesheet.css">
<!--    <meta http-equiv="refresh" content="60" /> -->
  </head>

  <body>

    <?php
      include 'php/get_metadata.php';
    ?>

    <div class="wrapper">
      <!--  <header class="header">Header</header> -->
     <article class="header">
       <p>
         <font size="6" color="green"><b>FUEL@OPNFV Developer's pipeline Dashboard</b></font></br>
         <img style="vertical-align:middle" src="images/LF.jpeg" height="90" width="150">
         <img style="vertical-align:middle" src="images/opnfv-extended.jpeg" height="75" width="150">
         <img style="vertical-align:middle" src="images/openstack.jpeg" height="150" width="150">
         <img style="vertical-align:middle" src="images/opendaylight.png" height="75" width="170">
         <img style="vertical-align:middle" src="images/fuel.png" height="75" width="160">
       </p>
     </article>

     <article class="ci-status">
       <p>
         CI-Pipeline status:
         <?php
           include('php/status.php');
         ?>
       </p>
     </article>

     <article class="vm-status">
       <p>
         KVM VM-status:
         <?php
           include('php/vm-status.php');
         ?>
       </p>
     </article>

     <article class="ci-history">
       <p>
         CI-History:
         <?php
           include('php/history.php');
         ?>
       </p>
     </article>

     <article class="ci-control">
       <p>
         CI-Control panel:
           <?php
             include('php/control.php');
           ?>
         </p>
       </article>

       <article class="ci-console">
         <p>
           CI-Console:
           </br>
           </br>
           <?php
              echo  '<iframe src="php/console.php" width="1000" height="520" scrolling="auto">';
              echo  '</iframe>';
           ?>
         </p>
       </article>

     </div>
  </body>
</html>
