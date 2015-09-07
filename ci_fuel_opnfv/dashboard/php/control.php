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
    <form name="OPNFV ci-light" action="php/ci_invoke.php" method="get">
      <p><b>Define CI pipeline options:</b></p>
      <i><u>Define branch/release to be used:</u></i></br>
      <input type="radio" name="release" value="master" checked>Latest (master)<br />
      <input type="radio" name="release" value="stable/arno">Stable/Arno<br />
      <input type="radio" name="release" value="arno.2015.1.0">Release Arno SR0<br />
      <input type="radio" name="release" value="arno.2015.1.1">Release Arno SR1<br />
      </br>
      <i><u>Define build options:</u></i></br>
      <input type="checkbox" name="build_params" value="no_cache">Invalidate build-cache<br />
      </br>
      <i><u>Define deployment options:</u></i></br>
      <input type="checkbox" name="deploy_params" value="ha">High availability<br />
      </br>
      <i><u>Define wanted CI-staging options:</u></i></br>
      <input type="checkbox" name="build_staging" value="build" checked>Build<br />
      <input type="checkbox" name="deploy_staging" value="deploy" checked>Deploy<br />
      <input type="checkbox" name="test_staging" value="test" checked>Test<br />
      </br>

      <i><u>Define optional .iso file location:</u></i></br>
      <input type="text" name="iso_file"<br />
      </br>
      </br>

      <input type="submit" value="Run">
      <input type="submit" value="Clean">
      <input type="submit" value="Help">
    </form>
    </p>
  </body>
</html>
