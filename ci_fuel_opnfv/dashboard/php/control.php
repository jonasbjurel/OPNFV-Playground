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
    <title> OPNFV CI Control panel </title>
<!--    <meta http-equiv="refresh" content="10" /> -->
  </head>
  <body>
    <form name="myWebForm" action="mailto:youremail@email.com" method="post">
      <p><b>Define CI pipeline options:</b></p>
      <i><u>Define release to be used:</u></i></br>
      <input type="checkbox" name="release" value="master" checked>Release - Latest (master)<br />
      <input type="checkbox" name="release" value="arno_sr0">Release Arno SR0<br />
      <input type="checkbox" name="release" value="arno_sr1">Release Arno SR1<br />
      </br>
      <i><u>Define build options:</u></i></br>
      <input type="checkbox" name="build_params" value="no_cache">Invalidate build-cache<br />
      </br>
      <i><u>Define deployment options:</u></i></br>
      <input type="checkbox" name="deploy_params" value="ha">High availability<br />
      </br>
      <i><u>Define wanted CI-staging options:</u></i></br>
      <input type="checkbox" name="staging" value="build" checked>Build<br /> 
      <input type="checkbox" name="staging" value="deploy" checked>Deploy<br /> 
      <input type="checkbox" name="staging" value="test" checked>Test<br />
      </br>
      <i><u>Define CI-run option:</u></i></br>     
      <input type="checkbox" name="ci_run_type" value="instant" checked>Instant CI-run<br />
      <input type="checkbox" name="ci_run_type" value="daily">Daily CI-run<br />
      </br>
      <input type="submit" value="Submit">
      <input type="submit" value="Purge CI-artifacts">
      <input type="submit" value="Help">
    </form>
    <p>
      <?php
      ?>
    </p>
  </body>
</html>
